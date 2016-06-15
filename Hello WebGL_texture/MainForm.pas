unit MainForm;

interface

uses
  SmartCL.System, SmartCL.Graphics, SmartCL.Controls, SmartCL.Components,
  SmartCL.Forms, SmartCL.Fonts, SmartCL.Borders, SmartCL.Application,
  Khronos.WebGl, GLS.Base, GLS.Vectors;

type
  TMainForm = class(TW3Form)
  private
    {$I 'MainForm:intf'}
  protected
    FCanvas : TW3GraphicContext;
    gl : JWebGLRenderingContext;
    rc : TGLRenderingContext;

    FTriangleBuffer: TGLArrayBuffer;
    FSquareBuffer: TGLArrayBuffer;
    FColorBuffer: TGLArrayBuffer;

    FFragmentShader: TGLFragmentShader;
    FVertexShader: TGLVertexShader;
    FShaderProgram: TGLShaderProgram;
    FVertexPosAttrib: Integer;
    FVertexColorAttrib: Integer;

    procedure InitializeObject; override;
    procedure Resize; override;

    procedure SetupScene;
    procedure Render;
  end;

implementation

{ TMainForm }

procedure TMainForm.InitializeObject;
begin
  inherited;
  {$I 'MainForm:impl'}
  FCanvas := TW3GraphicContext.Create(Self.Handle);
  gl := JWebGLRenderingContext(FCanvas.Handle.getContext('experimental-webgl'));

  rc := TGLRenderingContext.Create;
  rc.GL := gl;

  SetupScene;
  Render;
end;
 
procedure TMainForm.Resize;
begin
  inherited;

  // bit of hacking since we use a TW3GraphicContext directly
  // need to make a proper component for WebGL!
  FCanvas.Handle.width := Min(Width, 500);
  FCanvas.Handle.height := Min(Height, 500);
end;

procedure TMainForm.SetupScene;
begin
  gl.clearColor(0.0, 0.0, 0.25, 1.0); // Set clear color to black, fully opaque
  gl.clearDepth(1.0);                 // Clear everything
  gl.enable(gl.DEPTH_TEST);           // Enable depth testing
  gl.depthFunc(gl.LEQUAL);            // Near things obscure far things

  FColorBuffer := TGLArrayBuffer.Create(rc);
  FColorBuffer.SetData([
     1.0, 0.0, 0.0,
     0.0, 1.0, 0.0,
     0.0, 0.0, 1.0,
     1.0, 1.0, 0.0
    ], abuStatic);

  FTriangleBuffer := TGLArrayBuffer.Create(rc);
  FTriangleBuffer.SetData([
     0.0,  1.0,  0.0,
    -1.0, -1.0,  0.0,
     1.0, -1.0,  0.0
    ], abuStatic);

  FSquareBuffer := TGLArrayBuffer.Create(rc);
  FSquareBuffer.SetData([
     1.0,  1.0,  0.0,
    -1.0,  1.0,  0.0,
     1.0, -1.0,  0.0,
    -1.0, -1.0,  0.0
    ], abuStatic);

  // create vertex shader
  FVertexShader := TGLVertexShader.Create(rc);
  if not FVertexShader.Compile(#"
    attribute vec3 aVertexPosition;
    attribute vec3 aVertexColor;

    uniform mat4 uModelViewMatrix;
    uniform mat4 uProjectionMatrix;

    varying vec4 vColor;

    void main(void) {
       gl_Position = uProjectionMatrix * uModelViewMatrix * vec4(aVertexPosition, 1.0);
       // vColor = vec4(aVertexPosition, 1.0) + vec4(1, 1, 1, 0);
        vColor = vec4(aVertexColor, 1.0);
    }") then
    raise Exception.Create(FVertexShader.InfoLog);

  // create fragment shader
  FFragmentShader := TGLFragmentShader.Create(rc);
  if not FFragmentShader.Compile(#"
    precision mediump float;
    varying vec4 vColor;
    void main(void) {
       gl_FragColor = vColor; //vec4(1.0, 1.0, 1.0, 1.0);
    }") then
    raise Exception.Create(FFragmentShader.InfoLog);

  // create shader program and link shaders
  FShaderProgram := TGLShaderProgram.Create(rc);
  if not FShaderProgram.Link(FVertexShader, FFragmentShader) then
    raise Exception.Create(FShaderProgram.InfoLog);

  FVertexPosAttrib := FShaderProgram.AttribLocation("aVertexPosition");
  FVertexColorAttrib := FShaderProgram.AttribLocation("aVertexColor");

  asm
    // requestAnimFrame shim
    window.requestAnimFrame = (function(){
      return  window.requestAnimationFrame       ||
              window.webkitRequestAnimationFrame ||
              window.mozRequestAnimationFrame    ||
              window.oRequestAnimationFrame      ||
              window.msRequestAnimationFrame     ||
              function( callback ){
                window.setTimeout(callback, 1000 / 60);
              };
    })();
  end;
end;

procedure TMainForm.Render;
const
   cSpeed = 24 * 3600;
var
  ProjectionMatrix, ModelViewMatrix : Matrix4;
  ModelViewStack : array of Matrix4;
begin
  // set viewport to bounds of canvas
  gl.ViewportSet(0, 0, FCanvas.Handle.width, FCanvas.Handle.height);

  // clear background
  gl.clear(gl.COLOR_BUFFER_BIT);

  FShaderProgram.Use;

  ProjectionMatrix := Matrix4.CreatePerspective(45, FCanvas.width / FCanvas.height, 0.1, 100);
  ModelViewMatrix := Matrix4.Identity;

  FShaderProgram.SetUniform('uProjectionMatrix', ProjectionMatrix);

  gl.enableVertexAttribArray(FVertexPosAttrib);
  gl.enableVertexAttribArray(FVertexColorAttrib);

  // move cursor to triangle center
  ModelViewMatrix := ModelViewMatrix.Translate([-1.5, 0, -7]);

  ModelViewStack.Push(ModelViewMatrix);
  try
    ModelViewMatrix := ModelViewMatrix.RotateY(Frac(Now) * cSpeed);
    FShaderProgram.SetUniform('uModelViewMatrix', ModelViewMatrix);

    FTriangleBuffer.VertexAttribPointer(FVertexPosAttrib, 3, False, 0, 0);
    FColorBuffer.VertexAttribPointer(FVertexColorAttrib, 3, False, 0, 0);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  finally
    ModelViewMatrix := ModelViewStack.Pop;
  end;

  // move cursor relatively from triangle center to square center and rotate
  ModelViewMatrix := ModelViewMatrix.Translate([3.0, 0, 0]).RotateX(Frac(Now) * cSpeed);
  FShaderProgram.SetUniform('uModelViewMatrix', ModelViewMatrix);

  FSquareBuffer.VertexAttribPointer(FVertexPosAttrib, 3, False, 0, 0);
  gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);

  var renderCallback := @Render;
  asm
    window.requestAnimFrame(@renderCallback);
  end;
end;
 
end.
