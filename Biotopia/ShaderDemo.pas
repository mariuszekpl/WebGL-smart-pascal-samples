unit ShaderDemo;

interface

uses
  System.Types, Khronos.WebGL, GLS.Base, GLS.Vectors, GLCommon, Glyphs;

type
  TVertexData = record
    Vertices: TVertices;
    Normals: TVertices;
    Weights: TVertices;
    Radius: TFloatArray;
  end;

  // Vertex Window Ambient Occlusion
  TVWAOParams = record
    SampleStep: Integer;
    RadiusScale: Float;
    Opacity: Float;
  end;

  TDemoFragment = class
  private
    FStartTime: Float;
  protected
    procedure StartTimer;
    function ReadTimer: Float;
    function GetDuration: Float; virtual;
  public
    function HasCompleted: Boolean; virtual;
    procedure Activate; virtual;
    procedure Deactivate; virtual;
    procedure Render; virtual;
  end;

  TShaderDemoFragment = class(TDemoFragment)
  protected
    vertexShader: TGLVertexShader;
    fragmentShader: TGLFragmentShader;
    shaderProgram: TGLShaderProgram;
    squareBuffer : TGLArrayBuffer;
    vertexPosAttrib: Integer;
    vertexNormalAttrib: Integer;
    vertexWeightAttrib: Integer;
    radiusAttrib: Integer;

    VertexBuffer: TGLArrayBuffer;
    NormalBuffer: TGLArrayBuffer;
    WeightBuffer: TGLArrayBuffer;
    nverts: Integer;
    VWAOVertexShader: TGLVertexShader;
    VWAOFragmentShader: TGLFragmentShader;
    VWAOShaderProgram: TGLShaderProgram;
    VWAOVertexPosAttrib: Integer;
    VWAORadiusAttrib: Integer;
    VWAOVertexBuffer: TGLArrayBuffer;
    VWAORadiusBuffer: TGLArrayBuffer;
    nVWAO: Integer;
    SimpleVertexShader: TGLVertexShader;
    SimpleFragmentShader: TGLFragmentShader;
    SimpleShaderProgram: TGLShaderProgram;
    SimpleVertexPosAttrib: Integer;
    function GetFragmentShaderSource: string; virtual;
    function GetVertexShaderSource: string; virtual;
    procedure CreateBuffers; virtual;
    procedure GetVertexData(var Data: TVertexData); virtual; abstract;
    procedure DrawVWAO;
    procedure GetVWAOParams(var Params: TVWAOParams); virtual; 
    function GetModelViewMatrix: Matrix4; virtual;
    function GetProjectionMatrix: Matrix4; virtual;
    procedure Render; override;
    function UseVWAO: Boolean; virtual;
  public
    procedure Activate; override;
    procedure Deactivate; override;
  end;


const
  simple_vertex_shader: string = #"
    attribute vec3 aVertexPosition;
    varying vec2 texCoord;
    void main(void) {
      gl_Position = vec4(aVertexPosition, 1.0);
      texCoord = (aVertexPosition.xy + 1.0) * 0.5;
    }
  ";
  simple_fragment_shader: string = #"
    precision lowp float;

    uniform sampler2D source;
    varying vec2 texCoord;
    void main(void) {
      gl_FragColor = texture2D(source, texCoord);
    }
  ";
  iso_vertex_shader: string = #"
     attribute vec3 aVertexPosition;
     attribute vec3 aVertexNormal;
     attribute vec3 aVertexWeight;
     attribute float aRadius;

     uniform vec2 uScreenSize;
     uniform mat4 uMVMatrix;
     uniform mat3 uMVInvMatrix;
     uniform mat4 uPMatrix;

     varying vec4 vColor;
     //varying vec3 texCoord;
     //varying vec2 screenSize;
     varying vec3 normal;
     varying vec3 weight;

     void main(void) {
       vec3 v = aVertexPosition;
       gl_Position = uPMatrix * uMVMatrix * vec4(v, 1.0);
       //screenSize = uScreenSize;
       //normal = aVertexNormal;
       vec3 n = aVertexNormal * uMVInvMatrix;
       //vec4 nn = uPMatrix * vec4(n, 0.0); //aVertexNormal * uPInvMatrix;
       //n = nn.xyz;
       //if (n.z < 0.0) { n = -n; }
       normal = normalize(n);
       weight = aVertexWeight;
     }
  ";
  iso_fragment_shader: string = #"
      precision mediump float;

      uniform sampler2D source_a;
      uniform sampler2D source_b;
      uniform sampler2D source_c;
      uniform sampler2D source_d;
      uniform sampler2D depth;

      varying vec3 normal;
      varying vec3 weight;

      void main(void) {
        vec2 N = (normal.xy + 1.0)*0.5;
        if (normal.z < 0.0) { N = -N; }
        vec4 a = texture2D(source_a, N);
        vec4 b = texture2D(source_b, N);
        vec4 c = texture2D(source_c, N);
        vec4 d = texture2D(source_d, N);
        gl_FragColor = mix(mix(a, b, weight.x), mix(c, d, weight.y), weight.z);
      }
  ";

  VWAO_vertex_shader = #"
     attribute vec3 aVertexPosition;
     attribute float aRadius;

     uniform vec2 uScreenSize;
     uniform mat4 uMVMatrix;
     uniform mat3 uMVInvMatrix;
     uniform mat4 uPMatrix;

     varying vec2 screenSize;
     varying vec2 texCoord;
     varying float radius;

     void main(void) {
       //gl_Position = vec4(aVertexPosition, 1.0);
       texCoord = aVertexPosition.xy;
       screenSize = uScreenSize;
       gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
       gl_PointSize = aRadius/gl_Position.z;
       //gl_PointSize = abs(500.0/gl_Position.z) * aRadius;
       radius = aRadius;
     }
  ";

  VWAO_fragment_shader = #"
      precision mediump float;

      uniform sampler2D depthtex;
      uniform sampler2D source;
      uniform float uOpacity;

      varying float radius;
      varying vec2 texCoord;
      varying vec2 screenSize;

      float getDistanceSqr(vec2 v) {
        vec2 u = (v - 0.5) * 2.0;
        return dot(u, u);
      }

      void main(void) {
        vec2 coord = gl_FragCoord.xy / screenSize;
        float z = texture2D(depthtex, coord).x;
        //if (z < gl_FragCoord.z + 0.00002) discard;
        if (z < gl_FragCoord.z) discard;

        float d = getDistanceSqr(gl_PointCoord.xy);
        d = 1.0 - d;
        if (d <= 0.0) discard;

        gl_FragColor = vec4(0.0, 0.0, 0.0, d * uOpacity);
      }
  ";

implementation

var
  CameraIndex: Integer;

function GetCamera1(t, dur, delta: Float): Matrix4;
const
  PIDIV180 = Pi/180.0;
begin
  Result := Matrix4.CreatePerspective(45, canvas.width/canvas.height, 0.1, 60);
  if t < delta then
  begin
    t := 1 - t/delta;
    t := -t*t;
  end
  else if t > dur - delta then
  begin
    t := (t - (dur - delta)) / delta;
    t := t*t;
  end
  else
    exit;
  Result := Result.RotateY(20 * t * PIDIV180);
  Result := Result.Translate([0, 0, -t*60]);
  Result := Result.RotateY(80 * t * PIDIV180);
end;

function GetCamera2(t, dur, delta: Float): Matrix4;
const
  PIDIV180 = Pi/180.0;
begin
  Result := Matrix4.CreatePerspective(45, canvas.width/canvas.height, 0.1, 60);
  if t < delta then
  begin
    t := 1 - t/delta;
    t := -t*t;
  end
  else if t > dur - delta then
  begin
    t := (t - (dur - delta)) / delta;
    t := t*t;
  end
  else
    t := 0;
  Result := Result.RotateX(20 * t * PIDIV180);
  Result := Result.Translate([0, 0, -t*60]);
  Result := Result.RotateX(80 * t * PIDIV180);
end;

procedure NextCamera;
begin
  Inc(CameraIndex);
  if CameraIndex >= 2 then CameraIndex := 0;
end;

function GetCamera(t, dur, delta: Float): Matrix4;
begin
  case CameraIndex of
    0: Result := GetCamera1(t, dur, delta);
    1: Result := GetCamera2(t, dur, delta);
  end;
end;



{ TDemoFragment }

procedure TDemoFragment.Activate;
begin
end;

procedure TDemoFragment.Deactivate;
begin
end;

procedure TDemoFragment.Render;
begin
end;

procedure TDemoFragment.StartTimer;
begin
  FStartTime := Now();
end;

function TDemoFragment.GetDuration: Float;
begin
  Result := 20;
end;

function TDemoFragment.HasCompleted: Boolean;
begin
  Result := ReadTimer > GetDuration;
end;

function TDemoFragment.ReadTimer: Float;
begin
  Result := Frac(Now() - FStartTime) * cSpeed;
end;

{ TShaderDemoFragment }

procedure TShaderDemoFragment.Activate;
begin
  gl.enable(gl.DEPTH_TEST);           // Enable depth testing
  gl.depthFunc(gl.LEQUAL);            // Near things obscure far things
  gl.clearDepth(1.0);                 // Clear everything
  //gl.depthRange(0.0, 1.0);
  //gl.enable(gl.CULL_FACE);
  //gl.cullFace(gl.BACK);
  gl.clearColor(0.0, 0.0, 0.0, 1.0);  // Set clear color to black, fully opaque
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  //gl.colorMask(true, true, true, false);
  gl.clear(gl.COLOR_BUFFER_BIT);
  gl.bindFramebuffer(gl.FRAMEBUFFER, nil);

  fragmentShader := TGLFragmentShader.Create(rc);
  if not fragmentShader.Compile(GetFragmentShaderSource) then
    raise Exception.Create(fragmentShader.InfoLog);
  vertexShader := TGLVertexShader.Create(rc);
  if not vertexShader.Compile(GetVertexShaderSource) then
    raise Exception.Create(vertexShader.InfoLog);
  shaderProgram := TGLShaderProgram.Create(rc);
  if not shaderProgram.Link(vertexShader, fragmentShader) then
    raise Exception.Create(shaderProgram.InfoLog);

  vertexPosAttrib := shaderProgram.AttribLocation("aVertexPosition");
  vertexNormalAttrib := shaderProgram.AttribLocation("aVertexNormal");
  vertexWeightAttrib := shaderProgram.AttribLocation("aVertexWeight");
  radiusAttrib := shaderProgram.AttribLocation("aRadius");

  if VWAOEnabled then
  begin
    VWAOFragmentShader := TGLFragmentShader.Create(rc);
    if not VWAOFragmentShader.Compile(VWAO_fragment_shader) then
      raise Exception.Create(VWAOFragmentShader.InfoLog);
    VWAOVertexShader := TGLVertexShader.Create(rc);
    if not VWAOVertexShader.Compile(VWAO_vertex_shader) then
      raise Exception.Create(VWAOVertexShader.InfoLog);
    VWAOShaderProgram := TGLShaderProgram.Create(rc);
    if not VWAOShaderProgram.Link(VWAOVertexShader, VWAOFragmentShader) then
      raise Exception.Create(VWAOShaderProgram.InfoLog);
    VWAOVertexPosAttrib := VWAOShaderProgram.AttribLocation("aVertexPosition");
    VWAORadiusAttrib := VWAOShaderProgram.AttribLocation("aRadius");

    SimpleFragmentShader := TGLFragmentShader.Create(rc);
    if not SimpleFragmentShader.Compile(simple_fragment_shader) then
      raise Exception.Create(SimpleFragmentShader.InfoLog);
    SimpleVertexShader := TGLVertexShader.Create(rc);
    if not SimpleVertexShader.Compile(simple_vertex_shader) then
      raise Exception.Create(SimpleVertexShader.InfoLog);
    SimpleShaderProgram := TGLShaderProgram.Create(rc);
    if not SimpleShaderProgram.Link(SimpleVertexShader, SimpleFragmentShader) then
      raise Exception.Create(SimpleShaderProgram.InfoLog);
    SimpleVertexPosAttrib := SimpleShaderProgram.AttribLocation("aVertexPosition");
  end;
  CreateBuffers;
  StartTimer;
  NextCamera;
end;

procedure TShaderDemoFragment.Deactivate;
begin
  vertexShader.Free;
  fragmentShader.Free;
  shaderProgram.Free;
  squareBuffer.Free;
  VertexBuffer.Free;
  NormalBuffer.Free;
  WeightBuffer.Free;

  VWAOVertexShader.Free;
  VWAOFragmentShader.Free;
  VWAOShaderProgram.Free;
  VWAOVertexBuffer.Free;
  VWAORadiusBuffer.Free;

  SimpleFragmentShader.Free;
  SimpleVertexShader.Free;
  SimpleShaderProgram.Free;
end;

function TShaderDemoFragment.GetModelViewMatrix: Matrix4;
begin
  Result := Matrix4.Identity;
  Result := Result.Translate([0, 0, -22]);
  Result := Result.RotateX(-90);
  Result := Result.RotateZ(ReadTimer()*0.13);
end;

function TShaderDemoFragment.GetProjectionMatrix: Matrix4;
begin
  Result := GetCamera(ReadTimer, GetDuration, 3);
end;

function TShaderDemoFragment.UseVWAO: Boolean;
begin
  Result := GLCommon.VWAOEnabled;
end;

procedure TShaderDemoFragment.Render;
var
  projMat, mvMat: Matrix4;

  procedure DrawPoints(shaderProgram: TGLShaderProgram);
  begin
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.clear(gl.DEPTH_BUFFER_BIT);

    shaderProgram.Use;

    shaderProgram.SetUniform('uPMatrix', projMat);
    shaderProgram.SetUniform('uMVMatrix', mvMat);
    shaderProgram.SetUniform('uMVInvMatrix', mvMat.ToMatrix3.Inverse);

    shaderProgram.SetUniform('color', ColorTexID);
    shaderProgram.SetUniform('depth', DepthTexID);
    shaderProgram.SetUniform('source_a', EnvironmentTexID1);
    shaderProgram.SetUniform('source_b', EnvironmentTexID2);
    shaderProgram.SetUniform('source_c', EnvironmentTexID3);
    shaderProgram.SetUniform('source_d', EnvironmentTexID4);

    gl.enableVertexAttribArray(vertexPosAttrib);
    gl.enableVertexAttribArray(vertexNormalAttrib);
    gl.enableVertexAttribArray(vertexWeightAttrib);

    VertexBuffer.VertexAttribPointer(vertexPosAttrib, 3, false, 0, 0);
    NormalBuffer.VertexAttribPointer(vertexNormalAttrib, 3, false, 0, 0);
    WeightBuffer.VertexAttribPointer(vertexWeightAttrib, 3, false, 0, 0);

    gl.drawArrays(gl.TRIANGLES, 0, nverts);
  end;

begin
  projMat := GetProjectionMatrix;
  mvMat := GetModelViewMatrix;

  if UseVWAO then
  begin
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, colorTexture, 0);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, depthTexture, 0);
    DrawPoints(shaderProgram);
    DrawVWAO;
  end
  else
  begin
    gl.bindFramebuffer(gl.FRAMEBUFFER, nil);
    DrawPoints(shaderProgram);
  end;
end;

procedure TShaderDemoFragment.CreateBuffers;
var
  V: TVertices;
  Data: TVertexData;
  I: Integer;
  R: TFloatArray;
  Params: TVWAOParams;
begin
  VertexBuffer := TGLArrayBuffer.Create(rc);
  NormalBuffer := TGLArrayBuffer.Create(rc);
  WeightBuffer := TGLArrayBuffer.Create(rc);

  GetVertexData(Data);
  VerticesToBuffer(Data.Vertices, VertexBuffer);
  VerticesToBuffer(Data.Normals, NormalBuffer);
  VerticesToBuffer(Data.Weights, WeightBuffer);
  nverts := Length(Data.Vertices);

  if UseVWAO then
  begin
    GetVWAOParams(Params);
    VWAOVertexBuffer := TGLArrayBuffer.Create(rc);
    VWAORadiusBuffer := TGLArrayBuffer.Create(rc);
    I := 0;
    while I < nverts do
    begin
      V.Push(Data.Vertices[I]);
      if Length(Data.Radius) > 0 then
        R.Push(Data.Radius[I] * Params.RadiusScale)
      else
        R.Push(Params.RadiusScale);
      Inc(I, 40);
    end;
    VerticesToBuffer(V, VWAOVertexBuffer);
    VWAORadiusBuffer.SetData(R, abuStatic);
    nVWAO := Length(V);
    VWAOShaderProgram.Use;
    VWAOShaderProgram.SetUniform('uOpacity', Params.Opacity);

    squareBuffer := TGLArrayBuffer.Create(rc);
    squareBuffer.SetData([
        1.0,  1.0,  0.0,
       -1.0,  1.0,  0.0,
        1.0, -1.0,  0.0,
       -1.0, -1.0,  0.0
       ], abuStatic);
  end;
end;

function TShaderDemoFragment.GetFragmentShaderSource: string;
begin
  Result := iso_fragment_shader;
end;

function TShaderDemoFragment.GetVertexShaderSource: string;
begin
  Result := iso_vertex_shader;
end;

procedure TShaderDemoFragment.GetVWAOParams(var Params: TVWAOParams);
begin
  Params.SampleStep := 40;
  Params.RadiusScale := 1500;
  Params.Opacity := 0.05;
end;

procedure TShaderDemoFragment.DrawVWAO;
var
  projMat, mvMat: Matrix4;
  Params: TVWAOParams;
begin
  if not UseVWAO then exit;

  gl.bindFramebuffer(gl.FRAMEBUFFER, nil);
  //gl.clear(gl.COLOR_BUFFER_BIT);
  gl.disable(gl.DEPTH_TEST);

  // render ColorTexID to on-screen framebuffer
  SimpleShaderProgram.Use;
  SimpleShaderProgram.SetUniform('source', ColorTexID);
  squareBuffer.VertexAttribPointer(SimpleVertexPosAttrib, 3, false, 0, 0);
  gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);

  // blend ambient occlusion factor onto every pixel
  GetVWAOParams(Params);
  projMat := GetProjectionMatrix;
  mvMat := GetModelViewMatrix;
  VWAOShaderProgram.Use;
  VWAOShaderProgram.SetUniform('depthtex', DepthTexID);
  VWAOShaderProgram.SetUniform('source', ColorTexID);
  VWAOShaderProgram.SetUniform('uScreenSize', [Float(Canvas.width), Float(Canvas.height)]);
  VWAOshaderProgram.SetUniform('uPMatrix', projMat);
  VWAOshaderProgram.SetUniform('uMVMatrix', mvMat);
  VWAOshaderProgram.SetUniform('uMVInvMatrix', mvMat.ToMatrix3.Inverse);
  //VWAOshaderProgram.SetUniform('uScaleRadius',

  //squareBuffer.VertexAttribPointer(VWAOVertexPosAttrib, 3, false, 0, 0);
  //NormalBuffer.VertexAttribPointer(VWAOVertexNormalAttrib, 3, false, 0, 0);
  VWAORadiusBuffer.VertexAttribPointer(VWAORadiusAttrib, 1, false, 0, 0);
  VWAOVertexBuffer.VertexAttribPointer(VWAOVertexPosAttrib, 3, false, 0, 0);
  gl.drawArrays(gl.POINTS, 0, nVWAO);
  gl.enable(gl.DEPTH_TEST);
end;

end.
