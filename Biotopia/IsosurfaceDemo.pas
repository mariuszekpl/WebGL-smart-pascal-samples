unit IsosurfaceDemo;

interface

uses
  Khronos.WebGL, GLS.Base, GLS.Vectors, GLCommon,
  Glyphs, ShaderDemo, IsoSurfaces, MarchingCubes;

type
  TIsosurfaceDemoFragment = class(TShaderDemoFragment)
  protected
    procedure GetVertexData(var Data: TVertexData); override;
    function GetEvaluator: IEvaluator; virtual;
  end;

  TDoubleGyroidIsosurfaceDemoFragment = class(TIsosurfaceDemoFragment)
  protected
    procedure GetVWAOParams(var Params: TVWAOParams); override;
    procedure GetVertexData(var Data: TVertexData); override;
  end;

  TIcosahedronIsosurfaceDemoFragment = class(TIsosurfaceDemoFragment)
  protected
    function GetEvaluator: IEvaluator; override;
  end;

  TVirusIsosurfaceDemoFragment = class(TIsosurfaceDemoFragment)
  protected
    function GetEvaluator: IEvaluator; override;
    function GetModelViewMatrix: Matrix4; override;
    procedure GetVertexData(var Data: TVertexData); override;
  end;

implementation

{ TTextDemoFragment }

function TIsosurfaceDemoFragment.GetEvaluator: IEvaluator;
begin
  Result := nil;
end;

procedure TIsosurfaceDemoFragment.GetVertexData(var Data: TVertexData);
var
  Isosurface: IEvaluator;
  Vertices, Normals, Weights: TVertices;
begin
  Isosurface := GetEvaluator;
  MarchingCubes.MarchingCubes(45, Isosurface, Vertices, Normals);
  Weights.SetLength(Length(Vertices));
  Data.Vertices := Vertices;
  Data.Normals := Normals;
  Data.Weights := Weights;
end;

{ TDoubleGyroidIsosurfaceDemoFragment }

procedure TDoubleGyroidIsosurfaceDemoFragment.GetVertexData(var Data: TVertexData);
const
  nres = 54;
var
  Surface: TDoubleGyroidIsosurface;
  Vertices, Normals, Weights: TVertices;
  I, M, N: Integer;
begin
  Surface := TDoubleGyroidIsosurface.Create;
  try
    Surface.RADIUS := 7.3;
    Surface.DISTANCE := 0.95;
    MarchingCubes.MarchingCubes(nres, Surface as IEvaluator, Vertices, Normals);

    M := Length(Vertices);
    Weights.SetLength(M);
    for I := 0 to M - 1 do
      Weights[I] := [1.0, 0.0, 1.0];

    Surface.DISTANCE := 0.5;
    Surface.NEGATE := True;
    MarchingCubes.MarchingCubes(nres, Surface as IEvaluator, Vertices, Normals);

    N := Length(Vertices);
    Weights.SetLength(N);
    for I := M to N - 1 do
      Weights[I] := [0.0, 0.0, 0.0];

    Data.Vertices := Vertices;
    Data.Normals := Normals;
    Data.Weights := Weights;
  finally
    Surface.Free;
  end;
end;

procedure TDoubleGyroidIsosurfaceDemoFragment.GetVWAOParams(var Params: TVWAOParams);
begin
  Params.SampleStep := 300;
  Params.Opacity := 0.2;
  Params.RadiusScale := 1100;
end;

{ TIcosahedronIsosurfaceDemoFragment }

function TIcosahedronIsosurfaceDemoFragment.GetEvaluator: IEvaluator;
begin
  Result := TIcosahedronIsosurface.Create;
end;

{ TVirusIsosurfaceDemoFragment }

function TVirusIsosurfaceDemoFragment.GetEvaluator: IEvaluator;
begin
  Result := TVirusIsosurface.Create;
end;

function TVirusIsosurfaceDemoFragment.GetModelViewMatrix: Matrix4;
begin
  Result := inherited;
  Result := Result.Scale(5);
end;

procedure TVirusIsosurfaceDemoFragment.GetVertexData(var Data: TVertexData);
var
  I: Integer;
begin
  inherited GetVertexData(Data);
  for I := 0 to High(Data.Vertices) do
    Data.Weights[I] := [0.0,0.0,Data.Vertices[I].Length];
end;

end.
