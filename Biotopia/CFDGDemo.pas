unit CFDGDemo;

interface

{$DEFINE USEISOSURFACE}
{$DEFINE DEPTHBUFFER}

uses 
  Khronos.WebGl, GLS.Base, GLS.Vectors, GLCommon, MainForm,
  MarchingCubes, Isosurfaces, Glyphs, ShaderDemo;

type
  TCFDGDemoFragment = class(TShaderDemoFragment)
  protected
    function GetCFDGSource: string; virtual; abstract;
    procedure GetVertexData(var Data: TVertexData); override;
  public
    procedure Render; override;
  end;

  TCFDGTreeDemo = class(TCFDGDemoFragment)
  public
    procedure Activate; override;
    procedure GetVWAOParams(var Params: TVWAOParams); override;

    function GetCFDGSource: string; override;
    function GetModelViewMatrix: Matrix4; override;
  end;

  TCFDGTendrilsDemo = class(TCFDGDemoFragment)
  public
    procedure Activate; override;
    function GetCFDGSource: string; override;
  end;

  TCFDGSphereFlakeDemo = class(TCFDGDemoFragment)
  public
    function GetCFDGSource: string; override;
    function GetModelViewMatrix: Matrix4; override;
    procedure GetVWAOParams(var Params: TVWAOParams); override;
  end;

  TCFDGDNADemo = class(TCFDGDemoFragment)
  public
    function GetCFDGSource: string; override;
    //function GetProjectionMatrix: Matrix4; override;
    function GetModelViewMatrix: Matrix4; override;
  end;

  TCFDGShellDemo = class(TCFDGDemoFragment)
  public
    function GetCFDGSource: string; override;
    function GetModelViewMatrix: Matrix4; override;
  end;

  TCFDGFernDemo = class(TCFDGDemoFragment)
  protected
    procedure GetVWAOParams(var Params: TVWAOParams); override;
  public
    function GetCFDGSource: string; override;
    function GetModelViewMatrix: Matrix4; override;
  end;

implementation

uses
  CFDGParser;

const
  cfdg_script: string = #"
    startshape v

    rule v 20{
      ball{s 4}
    }

    rule v 2{
      go{s 4}
    }

    rule go{
      ball{}
      go{x 0.5 s 0.9}
    }

    rule ball{
      CIRCLE { }
      ballshading {s 0.99 r 45 b .2 hue 60 sat .5 }
    }

    rule ballshading {
      CIRCLE {}
      ballshading { b +0.1 s 0.9 0.8 y .08 sat -0.1 }
    }
  ";

  cfdg_script_2: string = #"

    startshape ARM

    rule ARM 98 {
      CIRCLE{}
      CIRCLE {size 0.9 brightness 1}
      ARM { y 0.2 size 0.99 rotate 3}
    }
    rule ARM 2 {
      CIRCLE {}
      CIRCLE {size 0.9 brightness 1}
      ARM { y 0.2 size 0.99 flip 90}
      //ARM {y 0.2 size 0.6 brightness 0.2}
    }
    rule ARM 3 {
      CIRCLE {}
      CIRCLE {size 0.9 brightness 1}
      ARM { y 0.2 size 1 rotate 2}
    }
  ";

  cfdg_script_3: string = #"

// crest of titan
startshape FLOWER

rule FLOWER{
10*{r 36 x 4}SWIRLS{}
FLOWER5{r 20 x 2 y 6.2 s 0.7}
}

rule FLOWER5{
5*{r 72}SWIRL{r 180 x 4}
}

rule SWIRLS{
SWIRL{x 14 r 220}
SWIRL{x 6.6 r -90 flip 90}
}

rule SWIRL{
STRIPES{}
SWIRL{r 2.3 y 0.1 s 0.99}
}

rule STRIPES{
4*{x 1.1 hue -20 sat -0.08 b 0.00}
CIRCLE{s 1 2 hue 237.9946 sat 0.4914 b 0.4980 a -0.8}
}
  ";

  cfdg_script_4: string = #"

startshape Y

rule X{
  3*{rz 120}Y{rx 60}
  3*{rz 120}Y{rx 120}
}

rule Y{
	CIRCLE{}
//	CIRCLE{}
	Z{s 0.90 z 0.45}
}

rule Z 60 {
  Y{}
}

rule Z 10 {
  //Y{}
  3*{rz 120}Y{rx 60}
}
  ";

  cfdg_sphereflake: string = #"
    startshape origin
    minsize 0.02

    rule origin{
      SPHERE{w 1}
      3*{r 90 0 90}plane{s 0.6666}
    }
    rule plane{
      next{z 1.618033988 y 1 }
      next{z 1.618033988 y -1 }
      next{z -1.618033988 y 1 }
      next{z -1.618033988 y -1 }
    }
    rule next{
      origin{s 0.5}
    }
  ";

  cfdg_spiral: string = #"
    startshape origin
    minsize 0.008

    rule origin{
      scaled{s 0.15}
    }
    rule scaled{
      TORUS{}
      20*{z 2 rz -10 ry -10}ball{}
      20*{z -2 rz 10 ry 10}ball{}
    }
    rule ball{
      TORUS{}
    }
  ";

  cfdg_tendrils: string = #"
    startshape TENDRILS
    minsize 0.02

    rule TENDRILS{
      MOVETO {}
      ARM{ry -30}
      MOVETO {}
      ARM{rz 180}
      MOVETO {}
      ARM{rz 180 rx 135 ry 45}
      MOVETO {}
      ARM{rx 135}
      MOVETO {}
      ARM{rz 45 rx -35}
      MOVETO {}
      ARM{rz 145 ry -85}
      MOVETO {}
      ARM{rz 245 ry 35 rx 40}
    }
    rule ARM 98 {
      LINETO{}
      ARM { z 0.2 size 0.99 rx 3 u 0.0075}
    }
    rule ARM 2 {
      LINETO {}
      RARM {z 0.2 size 0.99}
      MOVETO {}
      ARM {z 0.2 size 0.6 brightness 0.2}
    }
    rule ARM 3 {
      LINETO {}
      ARM {z 0.2 size 1 rx 2}
    }
    rule RARM 2{
      ARM{rz 180}
    }
    rule RARM{
      ARM{rz 120}
    }
    rule RARM{
      ARM{rz 60}
    }
    rule RARM{
      ARM{rz -120}
    }
    rule RARM{
      ARM{rz -60}
    }
  ";

  cfdg_dna: string = #"
    startshape DNA

    rule DNA{
      60*{rz 15 z 1.4 w 0.02} X{z -30 rx 90}
    }
    rule ATOM{
      SPHERE{RADIUS 1 rz 90}
    }
    rule X{
      ATOM{z -5.0 u 1 v 1}
      ATOM{z 5.0}
      MOVETO{z -5.0 s 0.25}
      LINETO{z 5.0 s 0.25 u 0.25 w 0.5 v 0.5}
    }
  ";

  cfdg_tree: string = #"
    startshape START
    minsize 0.04

    rule START {
      TREE {u 0.6 v 0.2 w 0.3}
    }

    rule TREE 0.9 {
      LINETO {}
      TREE { z 1.8 ry 25 s 0.9 brightness 0.02 hue 2 sat 1 w 0.05}
      MOVETO{}
      TREE { z 1.8 ry -25 s 0.9 brightness 0.02 hue 2 sat 1 w 0.05}
      MOVETO {}
    }

    rule TREE 0.5 {
      TREE{rz 23}
    }
    rule TREE 0.5 {
      TREE{rz 90}
    }
    rule TREE 0.5 {
      TREE{rz -90}
    }

    rule TREE 0.5 {
        LINETO {}
        TREE { z 1.8 ry 30 s 0.9 hue 2 sat 1 }
        MOVETO {}
    }

    rule TREE 0.5 {
        LINETO {}
        TREE { z 1.8 ry -30 s 0.9 hue 2 sat 1 }
        MOVETO {}
    }

    rule TREE 0.1 {}
  ";

  cfdg_shell: string = #"
    startshape START

    rule START {
      MOVETO{x -1.0 y 1}
      SHELL{x -1.0 y 1}
    }
    rule SHELL {
    	//RING{}
      LINETO{u 1.0 v 1.0 w 0.3}
    	SHELL{ z 0.08 rz 0.22 rx 2 s 0.997 w 0.0015}
      MOVETO{}
    }

  ";

  cfdg_fern: string = #"
startshape main
//minsize 0.025
rule main {
  ferns{}
  ferns{ry -30 rx 36 s 0.8}
  ferns{ry -60 s 0.6}
}
rule ferns{
  MOVETO{}
  5*{rx 72}fern {}
}
rule fern {
  LINETO {RADIUS 0.1 w 1}
  fern { z 0.4 s 0.9 b -0.05 rx 4 ry 3 }
  MOVETO{}
  fern { z 0.4 s 0.42 b -0.05 rx -45 ry 2 }
  MOVETO{}
  fern { z 0.4 s 0.42 b -0.05 rx 45 ry 2 }
  MOVETO{}
}

  ";

{ TCFDGDemoFragment }

procedure TCFDGDemoFragment.Render;
var
  projMat, mvMat : Matrix4;

  procedure DrawTriangles(shaderProgram: TGLShaderProgram);
  begin
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.clear(gl.DEPTH_BUFFER_BIT);

    shaderProgram.Use;
    gl.enableVertexAttribArray(vertexPosAttrib);
    gl.enableVertexAttribArray(vertexNormalAttrib);
    gl.enableVertexAttribArray(vertexWeightAttrib);

    shaderProgram.SetUniform('uPMatrix', projMat);
    shaderProgram.SetUniform('uMVMatrix', mvMat);
    shaderProgram.SetUniform('uMVInvMatrix', mvMat.ToMatrix3.Inverse);

    shaderProgram.SetUniform('color', ColorTexID);
    shaderProgram.SetUniform('depth', DepthTexID);
    shaderProgram.SetUniform('source_a', EnvironmentTexID1);
    shaderProgram.SetUniform('source_b', EnvironmentTexID2);
    shaderProgram.SetUniform('source_c', EnvironmentTexID3);
    shaderProgram.SetUniform('source_d', EnvironmentTexID4);

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
    DrawTriangles(shaderProgram);
    DrawVWAO;
  end
  else
    DrawTriangles(shaderProgram);
end;

procedure TCFDGDemoFragment.GetVertexData(var Data: TVertexData);
var
  CFDG: TCFDGProgram;
begin
  CFDG := ParseCFDG(GetCFDGSource, DrawableStore as ICFDGDrawableStore);
  try
    CFDG.Run();
    Data.Vertices := CFDG.Context.Vertices;
    Data.Normals := CFDG.Context.Normals;
    Data.Radius := CFDG.Context.Radius;
    Data.Weights := CFDG.Context.Weights;
  finally
    CFDG.Free;
  end;
end;

{ TCFDGTreeDemo }

function TCFDGTreeDemo.GetCFDGSource: String;
begin
  Result := cfdg_tree;
end;

function TCFDGTreeDemo.GetModelViewMatrix: Matrix4;
begin
  Result := Matrix4.Identity;
  Result := Result.Translate([0, -8, -22]);
  Result := Result.RotateX(-90);
  Result := Result.RotateZ(Frac(Now)*cSpeed*0.13);
end;


procedure TCFDGTreeDemo.Activate;
begin
  RandSeed(3);
  inherited;
end;

procedure TCFDGTreeDemo.GetVWAOParams(var Params: TVWAOParams);
begin
  Params.Opacity := 0.2;
  Params.RadiusScale := 2000;
  Params.SampleStep := 180;
end;

{ TCFDGTendrilsDemo }

procedure TCFDGTendrilsDemo.Activate;
begin
  RandSeed(2);
  inherited;
end;

function TCFDGTendrilsDemo.GetCFDGSource: String;
begin
  Result := cfdg_tendrils;
end;

{ TCFDGSphereFlakeDemo }

function TCFDGSphereFlakeDemo.GetCFDGSource: String;
begin
  Result := cfdg_sphereflake;
end;

function TCFDGSphereFlakeDemo.GetModelViewMatrix: Matrix4;
begin
  Result := inherited; //Matrix4.Identity;
  //Result := Result.Translate([0, 0, -6]);
  Result := Result.Scale(4);
  Result := Result.RotateX(-90);
  Result := Result.RotateZ(ReadTimer*0.13);
end;

procedure TCFDGSphereFlakeDemo.GetVWAOParams(var Params: TVWAOParams);
begin
  Params.Opacity := 0.04;
  Params.RadiusScale := 6000;
  Params.SampleStep := 180;
end;

{ TCFDGDNADemo }

function TCFDGDNADemo.GetCFDGSource: String;
begin
  Result := cfdg_dna;
end;

function TCFDGDNADemo.GetModelViewMatrix: Matrix4;
begin
  Result := inherited;
  Result := Result.RotateZ(ReadTimer*0.4);
  Result := Result.RotateY(ReadTimer*0.2);
end;

{ TCFDGShellDemo }

function TCFDGShellDemo.GetCFDGSource: String;
begin
  Result := cfdg_shell;
end;

function TCFDGShellDemo.GetModelViewMatrix: Matrix4;
var
  t: Float;
begin
  t := ReadTimer;
  Result := Matrix4.Identity;
  Result := Result.Translate([0, 0, -12]);
  Result := Result.RotateY(-t*0.1-70);
  Result := Result.RotateX(t*0.23);
end;

{ TCFDGFernDemo }

function TCFDGFernDemo.GetCFDGSource: String;
begin
  Result := cfdg_fern;
end;

function TCFDGFernDemo.GetModelViewMatrix: Matrix4;
begin
  Result := Matrix4.Identity;
  Result := Result.Translate([0, 0, -22]);
  Result := Result.Scale(4);
  Result := Result.RotateY(ReadTimer*0.1);
  Result := Result.RotateZ(-90);
end;

procedure TCFDGFernDemo.GetVWAOParams(var Params: TVWAOParams);
begin
  Params.SampleStep := 40;
  Params.RadiusScale := 1500;
  Params.Opacity := 0.05;
end;

end.
