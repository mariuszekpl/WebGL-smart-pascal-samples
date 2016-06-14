unit Shaders;

interface

uses 
  SmartCL.System, ShaderDemo, GLS.Base, GLS.Vectors, Khronos.WebGL, GLCommon;

type
  TLayer = array [0..5] of Vector2;

  TPlaneDemoFragment = class(TDemoFragment)
  protected
    squareBuffer : TGLArrayBuffer;
    fragmentShader : TGLFragmentShader;
    vertexShader : TGLVertexShader;
    shaderProgram : TGLShaderProgram;
    vertexPosAttrib : Integer;
  public
    function HasCompleted: Boolean; override;
    procedure Activate; override;
    procedure Deactivate; override;
    procedure Render; override;
  end;

const
  vertex_shader: string = #"
      attribute vec3 aVertexPosition;
      uniform mat4 uPMatrix;
      varying vec3 texCoord;

      void main(void) {
         texCoord = aVertexPosition;
         gl_Position = vec4(aVertexPosition, 1.0);
      }
  ";

  fragment_shader: string = #"
      precision mediump float;
      struct layer {
        vec2 direction;
        vec2 offset;
      };

      uniform sampler2D source;
      uniform layer layers[6];
      uniform float offset;
      varying vec3 texCoord;

      bool getValue(layer l) {
        float z = dot(l.direction, vec2(texCoord.x, texCoord.y));
        return fract(z * 0.5) < 0.5;
      }

      void main(void) {
         float v = float(getValue(layers[0]) ^^ getValue(layers[1]) ^^ getValue(layers[2])
           ^^    getValue(layers[3]) ^^ getValue(layers[4]) ^^ getValue(layers[5]));
         gl_FragColor = vec4(v, v, v, 0.1);
      }
  ";


implementation

function GetNormal(Angle, Radius: Float): Vector2;
begin
  Result[0] := Cos(Angle*2*Pi) * Radius;
  Result[1] := Sin(Angle*2*Pi) * Radius;
end;

const
  MAX_LAYERS = 9;

function GetLayer(Index: Integer): TLayer;
const
  SQRT2 = 1.41421356;
  SQRT3 = 1.732050808;
begin
//  Result := [[0.0,4.0], [2.0/6,4.0], [4.0/6,4.0], [0.0/6,0.01], [0.0/6,4.0], [0/6,2.0]];
  //Result := [[0.0,1.0], [0.0/6,2.0], [0.0/6,4.0], [0.0/6,0.01], [0.0/6,4.0], [0/6,2.0]];
  //Result := [[0.0,4.0], [2.0/6,4.0], [4.0/6,4.0], [1.0/6,4.0], [1.0/6,4.0], [1/6,4.0]];
  case Index of
    // lines
    0: Result := [[0.0,4.0], [1.0/6,8.0], [2.0/6,4.0], [1.0/6,8.0], [2.0/6,4.0], [3/6,8.0]];
    // stars
    1: Result := [[0.0,4.0], [1.0/6,4.0], [2.0/6,4.0], [0.0,1.0], [1.0/6,1.0], [2/6,1.0]];
    // stars
    2: Result := [[0.0,4.0], [2.0/6,4.0], [4.0/6,4.0], [0.0,1.0], [1.0/6,1.0], [2/6,1.0]];
    // triangles
    3: Result := [[0.0,2.0], [0.0/6,4.0], [0.0/6,8.0], [0.0/6,0.01], [0.0/6,4.0], [0/6,2.0]];
    //Result := [[0.0,4.0], [2.0/6,4.0], [4.0/6,4.0], [0.0,0.001], [2.0/6,0.001], [4/6,0.001]];
    // stars
    4: Result := [[0.0,4.0], [1.0/6,8.0], [2.0/6,4.0], [3.0/6,8.0], [4.0/6,4.0], [5/6,8.0]];
    // stars
    5: Result := [[0.0,4.0], [0.0,8.0], [1.0/6,4.0], [1.0/6,8], [2/6,4.0], [2.0/6,8.0]];
    6: Result := [[0.0,4.0], [0.0/8,4.0], [2.0/8,4.0], [0.0/8,4.0], [0.0,4.0], [0.0,4.0]];
    // diamonds
    7: Result := [[0.0,4.0], [1.0/8,4.0*SQRT2], [2.0/8,4.0], [3.0/8,4.0*SQRT2], [0.0,4.0], [0.0,4.0]];
    // trihexagons
    8: Result := [[0.0,4.0], [1.0/12,4.0*SQRT3], [2.0/12,4.0], [3.0/12,4.0*SQRT3], [4.0/12,4.0], [5.0/12,4.0*SQRT3]];
  end;
end;

var
  LayerIndex: Integer = -1;
var
  t0: Float;

function SmoothStep(W, X, Y: Float): Float;
var
  t: Float;
begin
  t := clamp((W - X) / (Y - X), 0, 1); //, 0, 1);
  Result := t * t * (3 - 2 * t );
end;

function UpdateWeight: Float;
const
  MAX_T = 15;
var
  t, dt: Float;
begin
  t := Now * CSpeed;
  dt := Abs(t - t0);
  if dt > MAX_T then
  begin
    t0 := t;
    LayerIndex := (LayerIndex + 1) mod MAX_LAYERS;
    Result := 0;
  end
  else
  begin
    if dt > 10 then
      Result := SmoothStep((dt - 10) * (1/5), 0, 1);
  end;
end;

function Interpolate(V1, V2: Vector2; W: Float): Vector2; overload;
begin
  Result[0] := V1[0] + W * (V2[0] - V1[0]);
  Result[1] := V1[1] + W * (V2[1] - V1[1]);
end;

function Interpolate(L1, L2: TLayer; W: Float): TLayer; overload;
begin
  Result[0] := Interpolate(L1[0], L2[0], W);
  Result[1] := Interpolate(L1[1], L2[1], W);
  Result[2] := Interpolate(L1[2], L2[2], W);
  Result[3] := Interpolate(L1[3], L2[3], W);
  Result[4] := Interpolate(L1[4], L2[4], W);
  Result[5] := Interpolate(L1[5], L2[5], W);
end;
function L2L(L: TLayer; A: Float): TLayer;
begin
  L[0] := GetNormal(L[0][0] + A, L[0][1]);
  L[1] := GetNormal(L[1][0] + A, L[1][1]);
  L[2] := GetNormal(L[2][0] + A, L[2][1]);
  L[3] := GetNormal(L[3][0] + A, L[3][1]);
  L[4] := GetNormal(L[4][0] + A, L[4][1]);
  L[5] := GetNormal(L[5][0] + A, L[5][1]);
  Result := L;
end;

function GetInterpolatedLayer(angle: Float): TLayer;
var
  L1, L2: TLayer;
begin
  L1 := GetLayer(LayerIndex);
  L2 := GetLayer((LayerIndex + 1) mod MAX_LAYERS);
  L1 := L2L(L1, angle);
  L2 := L2L(L2, angle);
  Result := Interpolate(L1, L2, UpdateWeight);
end;

{ TPlaneDemoFragment }

procedure TPlaneDemoFragment.Activate;
begin
  gl.disable(gl.DEPTH_TEST);           // Enable depth testing
  gl.clearColor(0.0, 0.0, 0.25, 1.0); // Set clear color to black, fully opaque
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  //gl.colorMask(true, true, true, false);
  gl.clear(gl.COLOR_BUFFER_BIT);

  squareBuffer := TGLArrayBuffer.Create(rc);
  squareBuffer.SetData([
      1.0,  1.0,  0.0,
     -1.0,  1.0,  0.0,
      1.0, -1.0,  0.0,
     -1.0, -1.0,  0.0
     ], abuStatic);


  fragmentShader := TGLFragmentShader.Create(rc);
  if not fragmentShader.Compile(fragment_shader) then
    raise Exception.Create(fragmentShader.InfoLog);
  vertexShader := TGLVertexShader.Create(rc);
  if not vertexShader.Compile(vertex_shader) then
    raise Exception.Create(vertexShader.InfoLog);
  shaderProgram := TGLShaderProgram.Create(rc);
  if not shaderProgram.Link(vertexShader, fragmentShader) then
    raise Exception.Create(shaderProgram.InfoLog);
  vertexPosAttrib := shaderProgram.AttribLocation("aVertexPosition");

  StartTimer;
end;

procedure TPlaneDemoFragment.Deactivate;
begin
  fragmentShader.Free;
  vertexShader.Free;
  shaderProgram.Free;
  squareBuffer.Free;
end;

function TPlaneDemoFragment.HasCompleted: Boolean;
begin
  Result := False;
end;

procedure TPlaneDemoFragment.Render;
var
  projMat, mvMat : Matrix4;
  L: TLayer;
  angle: Float;
begin
  gl.bindFramebuffer(gl.FRAMEBUFFER, nil);

  shaderProgram.Use;

  projMat := Matrix4.Identity;
  mvMat := Matrix4.Identity;

  shaderProgram.SetUniform('uPMatrix', projMat);
  gl.enableVertexAttribArray(vertexPosAttrib);

  shaderProgram.SetUniform('source', 0);
  angle := Frac(ReadTimer*0.1);

  L := GetInterpolatedLayer(angle);
  shaderProgram.SetUniform('layers[0].direction', L[0]);
  shaderProgram.SetUniform('layers[1].direction', L[1]);
  shaderProgram.SetUniform('layers[2].direction', L[2]);
  shaderProgram.SetUniform('layers[3].direction', L[3]);
  shaderProgram.SetUniform('layers[4].direction', L[4]);
  shaderProgram.SetUniform('layers[5].direction', L[5]);

  squareBuffer.VertexAttribPointer(vertexPosAttrib, 3, false, 0, 0);
  gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
end;


end.
