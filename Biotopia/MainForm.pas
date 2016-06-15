unit MainForm;

interface

uses 
  SmartCL.System, SmartCL.Graphics, SmartCL.Controls, SmartCL.Components,
  SmartCL.Forms, SmartCL.Fonts, SmartCL.Borders, SmartCL.Application,
  W3C.Canvas2DContext, Khronos.WebGl, GLS.Base, GLS.Vectors, GLCommon,
  BinaryFile, Shaders, ShaderDemo;

type
  TMainForm = class(TW3form)
  private
   {$I 'MainForm:intf'}
   FFragmentIndex: Integer;
   function GetFragment: TDemoFragment;
  protected
    procedure InitializeObject; override;
    procedure FinalizeObject; override;
    procedure Resize; override;
    procedure LoadTextures;
    procedure SetupScene;
    procedure Render;
    procedure NextFragment;

    property Fragment: TDemoFragment read GetFragment;
  end;

var
  Fragments: array of TDemoFragment;

implementation

uses
  CFDGDemo, TextDemo, IsosurfaceDemo;

{ TForm1 }

procedure TMainForm.InitializeObject;
begin
  inherited;
  {$I 'MainForm:impl'}
  AlphaBlend := False;
  Transparent := False;
  canvas := TW3GraphicContext.Create(Self.Handle);
  InitializeWebGL(canvas);

  // Create demo fragments
  Fragments.Push(TTextDemoFragment.Create('BIOTOPIA',10));
  Fragments.Push(TTextDemoFragment.Create('DIRECTED BY;MATTIAS ANDERSSON',22));
  Fragments.Push(TTextDemoFragment.Create('< PART I >;;ISOSURFACES',14));
  Fragments.Push(TTextDemoFragment.Create('A VIRUS',14));
  Fragments.Push(TVirusIsosurfaceDemoFragment.Create);
  Fragments.Push(TTextDemoFragment.Create('ICOSAHEDRON',14));
  Fragments.Push(TIcosahedronIsosurfaceDemoFragment.Create);
  Fragments.Push(TTextDemoFragment.Create('DOUBLE GYROID;;(PATIENCE PLEASE!)',20));
  Fragments.Push(TDoubleGyroidIsosurfaceDemoFragment.Create);

  Fragments.Push(TTextDemoFragment.Create('< PART II >;;3D-CFDG',14));
  Fragments.Push(TTextDemoFragment.Create('DNA SPIRAL',14));
  Fragments.Push(TCFDGDNADemo.Create);
  Fragments.Push(TTextDemoFragment.Create('SPHEREFLAKE',14));
  Fragments.Push(TCFDGSphereFlakeDemo.Create);
  Fragments.Push(TTextDemoFragment.Create('A SHELL',14));
  Fragments.Push(TCFDGShellDemo.Create);
  Fragments.Push(TTextDemoFragment.Create('FERNS',14));
  Fragments.Push(TCFDGFernDemo.Create);
  Fragments.Push(TTextDemoFragment.Create('TENDRILS',14));
  Fragments.Push(TCFDGTendrilsDemo.Create);
  Fragments.Push(TTextDemoFragment.Create('A TREE;;(PATIENCE!)',14));
  Fragments.Push(TCFDGTreeDemo.Create);
  Fragments.Push(TTextDemoFragment.Create('THE END',10));
  Fragments.Push(TTextDemoFragment.Create('< GREETINGS >;;ERIC GRANGE;CHRISTIAN BUDDE;THE REST OF;THE SMS TEAM',20));

  //Fragments.Push(TPlaneDemoFragment.Create);

  FFragmentIndex := 0;
  Fragment.Activate;

  SetupScene;
  LoadTextures;
  Render;
end;

procedure TMainForm.FinalizeObject;
begin
  inherited;
end;

procedure TMainForm.Resize;
var
  W, H: Integer;
begin
  inherited;

  // bit of hacking since we use a TW3GraphicContext directly
  // need to make a proper compoent for WebGL!
  W := Min(Width, 1024);
  H := Min(Height, 768);

  canvas.Handle.width := W;
  canvas.Handle.height := H;
  //canvas.Handle.style := 'left: auto; right: auto; top: auto; bottom: auto';
  if Assigned(gl) then
  begin
    gl.ViewportSet(0, 0, canvas.Handle.width, canvas.Handle.height);
    if VWAOEnabled then
    begin
      ActiveTexture(DepthTexID);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT, W, H, 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_SHORT, nil);
      ActiveTexture(ColorTexID);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, W, H, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil);
    end;
  end;
end;

function TMainForm.GetFragment: TDemoFragment;
begin
  Result := nil;
  if FFragmentIndex <= High(Fragments) then
    Result := Fragments[FFragmentIndex];
end;

procedure TMainForm.SetupScene;
begin
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


procedure TMainForm.NextFragment;
begin
  Inc(FFragmentIndex);
end;

procedure TMainForm.Render;
begin
  if Fragment.HasCompleted then
  begin
    Fragment.Deactivate;
    NextFragment;
    if not Assigned(Fragment) then Exit;
    Fragment.Activate;
  end;

  if Assigned(Fragment) then
    Fragment.Render;

  var renderCallback := @Render;
  asm
    window.requestAnimFrame(@renderCallback);
  end;
end;

procedure TMainForm.LoadTextures;
var
  tex: TTextureData;
begin
  tex := TTextureData.Create;
  tex.TextureID := EnvironmentTexID1;
  tex.LoadFromURL('./res/blue-ball.png');

  tex := TTextureData.Create;
  tex.TextureID := EnvironmentTexID2;
  tex.LoadFromURL('./res/red-ball.png');

  tex := TTextureData.Create;
  tex.TextureID := EnvironmentTexID3;
  tex.LoadFromURL('./res/green-ball.png');

  tex := TTextureData.Create;
  tex.TextureID := EnvironmentTexID4;
  tex.LoadFromURL('./res/orange-ball.png');
end;

end.