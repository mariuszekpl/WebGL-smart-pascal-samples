unit GLCommon;

interface

uses 
  SmartCL.Graphics, Khronos.WebGL, GLS.Base, GLS.Vectors;

const
  VWAOEnabled = False;
  cSpeed = 24 * 3600;

type
  TVertices = array of Vector3;

function CreateColorTexture(Filter: Integer = JWebGLRenderingContext.NEAREST): JWebGLTexture;
function CreateDepthTexture(Filter: Integer = JWebGLRenderingContext.NEAREST): JWebGLTexture;

const
  DepthTexID = 0;
  ColorTexID = 1;
  EnvironmentTexID1 = 2;
  EnvironmentTexID2 = 3;
  EnvironmentTexID3 = 4;
  EnvironmentTexID4 = 5;

var
  canvas : TW3GraphicContext;
  rc : TGLRenderingContext;
  gl : JWebGLRenderingContext;
  Framebuffer: JWebGLFramebuffer;
  ColorTexture: JWebGLTexture;
  DepthTexture: JWebGLTexture;
  DepthTextureExt: Variant;

procedure InitializeWebGL(Canvas: TW3GraphicContext);
procedure ActiveTexture(ID: Integer);
procedure VerticesToBuffer(const Vertices: TVertices; Buffer: TGLArrayBuffer);
procedure RandSeed(Seed: Integer);

implementation

procedure ActiveTexture(ID: Integer);
begin
  gl.activeTexture(gl.TEXTURE0 + ID);
end;

procedure InitializeWebGL(Canvas: TW3GraphicContext);
var
  attr: JWebGLContextAttributes;
begin
  attr := JWebGLContextAttributes.Create;
  attr.alpha := False;
  attr.stencil := False;
  attr.premultipliedAlpha := False;
  attr.preserveDrawingBuffer := False;
  attr.antialias := True;
  attr.depth := True;
  gl := JWebGLRenderingContext( Canvas.Handle.getContext('experimental-webgl', attr));

  rc := TGLRenderingContext.Create;
  rc.GL := gl;

  if VWAOEnabled then
  begin
    depthTextureExt := gl.getExtension('WEBKIT_WEBGL_depth_texture'); // Or browser-appropriate prefix
    if VarIsNull(depthTextureExt) then
      raise Exception.Create('Error: no WEBKIT_WEBGL_depth_texture support!');

    Framebuffer := gl.createFrameBuffer();
    ActiveTexture(DepthTexID);
    DepthTexture := CreateDepthTexture;
    ActiveTexture(ColorTexID);
    ColorTexture := CreateColorTexture;

    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, colorTexture, 0);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, depthTexture, 0);
  end;
end;
//----------------------------------------------------------------------------//
function CreateColorTexture(Filter: Integer): JWebGLTexture;
begin
  Result := gl.CreateTexture;
  gl.bindTexture(gl.TEXTURE_2D, Result);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, Filter);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, Filter);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
end;

function CreateDepthTexture(Filter: Integer): JWebGLTexture;
begin
  Result := gl.CreateTexture;
  gl.bindTexture(gl.TEXTURE_2D, Result);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, Filter);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, Filter);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  //gl.texImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT, size, size, 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_SHORT, null);
end;

procedure VerticesToBuffer(const Vertices: TVertices; Buffer: TGLArrayBuffer);
var
  I: Integer;
  Data: array of Float;
begin
  Data := [];
  for I := 0 to High(Vertices) do
  begin
    Data.Push(Vertices[I][0]);
    Data.Push(Vertices[I][1]);
    Data.Push(Vertices[I][2]);
  end;
  Buffer.SetData(Data, abuStatic);
end;

procedure RandSeed(Seed: Integer);
var
  S: string;
begin
  S := Format('Random = $alea(%d)', [Seed]);
  asm
    eval(@S);
  end;
end;

end.
