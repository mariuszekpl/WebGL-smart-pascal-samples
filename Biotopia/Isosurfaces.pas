unit IsoSurfaces;

interface

uses
  GLCommon, GLS.Vectors, CFDGParser, MarchingCubes;

const
  DEFAULT_DIVISIONS = 9;

type
  TIsosurface = class(IEvaluator)
  public
    function GetValue(X, Y, Z: Float): Float; virtual; abstract;
    function GetConstraints: TConstraints; virtual; 
  end;

  TSphereIsosurface = class(TIsosurface)
  public
    constructor Create; 
    function GetValue(X, Y, Z: Float): Float; override;
    function GetConstraints: TConstraints; override;
    RADIUS: Float;
  end;

  TTorusIsosurface = class(TIsosurface)
  public
    constructor Create;
    function GetValue(X, Y, Z: Float): Float; override;
    function GetConstraints: TConstraints; override;
    MINRADIUS: Float;
    MAXRADIUS: Float;
  end;

  TRoundCubeIsosurface = class(TIsosurface)
  public
    function GetValue(X, Y, Z: Float): Float; override;
  end;

  TIcosahedronIsosurface = class(TIsosurface)
  public
    function GetValue(X, Y, Z: Float): Float; override;
    function GetConstraints: TConstraints; override;
  end;

  TVirusIsosurface = class(TIsosurface)
  public
    function GetValue(X, Y, Z: Float): Float; override;
    function GetConstraints: TConstraints; override;
  end;

  TDoubleGyroidIsosurface = class(TIsosurface)
  public
    constructor Create;
    function GetValue(X, Y, Z: Float): Float; override;
    function GetConstraints: TConstraints; override;
    NEGATE: Boolean;
    DISTANCE: Float;
    RADIUS: Float;
  end;


  TCFDGIsosurface = class(ICFDGDrawable)
  private
    FIsosurface: TIsosurface;
    FVertices: TVertices;
    FNormals: TVertices;
    //procedure SetIsosurface(Value: IIsosurface);
  public
    // BeginDraw/EndDraw
    procedure Draw(Context: TCFDGContext); virtual;
    procedure SetProperty(const PropName: string; Value: Float); virtual;
    procedure Prepare;
    property Isosurface: TIsosurface read FIsosurface write FIsosurface;
  end;

  TCFDGExtrudedLine = class(ICFDGDrawable)
  private
    FDivisions: Integer;
  public
    constructor Create; virtual;
    function GetDivisions: Integer; virtual;
    //procedure GetVertices(var Vertices, Normals: TVertices); virtual; abstract;
    procedure SetProperty(const PropName: string; Value: Float); virtual;
    procedure GetVertex(t: Float; var Vertex, Normal: Vector3); virtual; abstract;
    procedure GetVertices(var Vertices, Normals: TVertices); virtual;
    procedure Draw(Context: TCFDGContext);
    procedure Prepare;
    property Divisions: Integer read FDivisions write FDivisions;
    RADIUS: Float;
  end;

  TCFDGMoveTo = class(ICFDGDrawable)
  public
    procedure SetProperty(const PropName: string; Value: Float); virtual;
    procedure Draw(Context: TCFDGContext);
    procedure Prepare;
  end;

  TCFDGExtrudedLineNGon = class(TCFDGExtrudedLine)
  public
    constructor Create; override;
    procedure GetVertex(t: Float; var Vertex, Normal: Vector3); override;
  end;

  TCFDGDrawableStore = class(ICFDGDrawableStore)
  public
    function GetDrawable(const DrawableName: string): ICFDGDrawable;
  end;

var
  DrawableStore: TCFDGDrawableStore;

implementation


function UniformBox(Radius: Float): TConstraints;
begin
  Result.xmin := -radius;
  Result.xmax := radius;
  Result.ymin := -radius;
  Result.ymax := radius;
  Result.zmin := -radius;
  Result.zmax := radius;
end;


function TIsosurface.GetConstraints: TConstraints;
begin
  Result := UniformBox(1.0);
end;

function TSphereIsosurface.GetConstraints: TConstraints;
begin
  Result := UniformBox(RADIUS);
end;

constructor TSphereIsosurface.Create;
begin
  RADIUS := 1.0;
end;

function TSphereIsosurface.GetValue(X, Y, Z: Float): Float;
begin
  Result := Sqr(RADIUS) - (X*X + Y*Y + Z*Z);
end;

constructor TTorusIsosurface.Create;
begin
  MINRADIUS := 1.0;
  MAXRADIUS := 2.0;
end;

function TTorusIsosurface.GetValue(X, Y, Z: Float): Float;
begin
  //Result := 4.0 - (X*X + Y*Y + Z*Z);
  Result := sqr(MAXRADIUS - sqrt(sqr(x)+sqr(y)+sqr(z)))+sqr(z) - MINRADIUS;
end;

function TTorusIsosurface.GetConstraints: TConstraints;
begin
  Result := UniformBox(MAXRADIUS);
end;

function Cube(x: Float): Float;
begin
  Result := x*x*x;
end;

function Sqr4(x: Float): Float;
begin
  Result := sqr(sqr(x));
end;

function TRoundCubeIsosurface.GetValue(X, Y, Z: Float): Float;
begin
  Result := sqr4(x) + sqr4(y) + sqr4(z) - (sqr(x) + sqr(y) + sqr(z))
end;

function TIcosahedronIsosurface.GetValue(X, Y, Z: Float): Float;
const
  golden: Float = (1+sqrt(5))/2;
begin
  //Result := sqr4(x) + sqr4(y) + sqr4(z) - (sqr(x) + sqr(y) + sqr(z))
  // heart
  //Result := (cube(2 * Sqr(z) + Sqr(x) + Sqr(y) - 1) - 2 * sqr(x) * cube(-y));
  //Result := (cube(2 * Sqr(z) + Sqr(x) + Sqr(-y) - 1) * 0.5 - sqr(x) * cube(-y));
  //Result := Cube(2 * Sqr(z) + Sqr(x) + Sqr(-y) - 1) / 2 - sqr(x) * Cube(y);
  //Result := sqr(sqrt(x*x+y*y)-1) + z*z - 0.25;

  //Result := Sqr(x) + Sqr(y) + Sqr(z) - 1;
  // round cube with hole
  //Result := sqr4(x) + sqr4(y) + sqr4(z) - (sqr(x) + sqr(y) + sqr(z)-0.3)

  // icosohedron:

  if sqr(x) + sqr(y) + sqr(z) < 35 then
    Result := (cos(x + golden*y) + cos(x - golden*y) + cos(y + golden*z) + cos(y - golden*z) + cos(z - golden*x) + cos(z + golden*x)) - 2
  else
    Result := -1;
  //Result := -Result;

  //Result := cos(x) * sin(y) + cos(y) * sin(z) + cos(z) * sin(x);

  // torus constellation
(*
   Result :=
  (sqr(sqrt(x*x+y*y)-3) + z*z - 0.4) *
  (sqr(sqrt((x-4.5)*(x-4.5)+z*z)-3) + y*y - 0.4) *
  (sqr(sqrt((x+4.5)*(x+4.5)+z*z)-3) + y*y - 0.4 ) *
  (sqr(sqrt((y+4.5)*(y+4.5)+z*z)-3) + x*x - 0.4 ) *
  (sqr(sqrt((y-4.5)*(y-4.5)+z*z)-3) + x*x - 0.4 ) *
  (sqr(sqrt(x*x+y*y)-5) + z*z - 0.4);
*)
end;

function TIcosahedronIsosurface.GetConstraints: TConstraints;
begin
  Result := UniformBox(5.1);
end;

function TVirusIsosurface.GetValue(X, Y, Z: Float): Float;
begin
  Result :=
   -(sqr(x) + sqr(y) + sqr(z)) + cos(5*x)*cos(5*y)*cos(5*z)+0.245;
end;

function TVirusIsosurface.GetConstraints: TConstraints;
begin
  Result := UniformBox(1.0);
end;


{ TDoubleGyroidIsosurface }

constructor TDoubleGyroidIsosurface.Create;
begin
  NEGATE := False;
  DISTANCE := 0.85;
  RADIUS := 7.4;
end;

// star
// Result := (x*x*y*y*sqr(x*x-y*y)+y*y*z*z*sqr(y*y-z*z)+z*z*x*x*sqr(z*z-x*x))-4

// Credits: Torolf Sauermann
function TDoubleGyroidIsosurface.GetValue(X, Y, Z: Float): Float;
const
  radius = 7.4;
//  radius = 6.8;
//  radius = 3.4;
//  radius = 7.9;
var
  r: Float;
begin
/*  Result :=
    -sqr(cos(x) * sin(y) + cos(y) * sin(z) + cos(z) * sin(x))
    //*(cos(x) * sin(y) + cos(y) * sin(z) + cos(z) * sin(x))
    +0.05-exp(100.0*(x*x/64+y*y/64 + z*z/(1.6*64)*exp(-0.4*z/8) - 1));
*/
/*
  Result :=
    -(cos(x) * sin(y) + cos(y) * sin(z) + cos(z) * sin(x))
    *(cos(x) * sin(y) + cos(y) * sin(z) + cos(z) * sin(x))
    +0.02
    +exp((x*x+y*y+z*z)-32.0);
*/

  r := sqrt(sqr(x) + sqr(y) + sqr(z));
  Result := sqr(cos(x)*sin(z)+cos(y)*sin(x)+cos(z)*sin(y))-DISTANCE;

  //Result := 2 - (cos(x + (1+sqrt(5))/2*y) + cos(x - (1+sqrt(5))/2*y) + cos(y + (1+sqrt(5))/2*z) + cos(y - (1+sqrt(5))/2*z) + cos(z - (1+sqrt(5))/2*x) + cos(z + (1+sqrt(5))/2*x))
  //Result := sqr(cos(2*x)*sin(2*z)+cos(2*y)*sin(2*x)+cos(2*z)*sin(2*y))-0.85;
  //Result := abs(cos(2*x)*sin(2*z)+cos(2*y)*sin(2*x)+cos(2*z)*sin(2*y))-0.8;
  //Result := abs(cos(3*x)*sin(3*z)+cos(3*y)*sin(3*x)+cos(3*z)*sin(3*y))-0.85;
  //Result := abs(sqr(cos(x))*sqr(sin(z))+sqr(cos(y))*sqr(sin(x))+sqr(cos(z))*sqr(sin(y)))-0.9;
  //Result := abs(exp(cos(x))*exp(sin(z))+exp(cos(y))*exp(sin(x))+exp(cos(z))*exp(sin(y)))-1.9;
  //Result := abs(sin(cos(x))*cos(sin(z))+sin(cos(y))*cos(sin(x))+sin(cos(z))*cos(sin(y)))-1.3;
  //Result := abs(cos(cos(x))*sin(sin(z))+cos(cos(y))*sin(sin(x))+cos(cos(z))*sin(sin(y)))-1.9;
  //Result := (cos(x)*sin(z)+cos(y)*sin(x)+cos(z)*sin(y))-0.85;

  // regular with spheres
  //Result := abs(cos(x)*cos(z)+cos(y)*cos(x)+cos(z)*cos(y))-0.85;
  //Result := cos(cos(x)*sin(z)+cos(y)*sin(x)+cos(z)*sin(y))-0.85;


  if NEGATE then
    Result := -Result;
  if r > radius then
    Result := Result - sqr(r-radius);
end;

function TDoubleGyroidIsosurface.GetConstraints: TConstraints;
begin
  Result := UniformBox(RADIUS + 1.2);
end;

(*

4D Mandelbrot
              xi = mx
              yyy = my
              zzz = mz
              mx = mx*mx - my*my - mz*mz - mw*mw + x
              my = 2.0*my*xi + 2.0*mz*mw + y
              mz = 2.0*mz*xi + 2.0*yyy*mw + zz
              mw = 2.0*(mw*xi + yyy*zzz) + w
*)


{ TCFDGIsosurface }

procedure TCFDGIsosurface.Draw(Context: TCFDGContext);
var
  I: Integer;
begin
  for I := 0 to High(FVertices) do
    Context.DrawVertex(FVertices[I], FNormals[I]);
end;

procedure TCFDGIsosurface.Prepare;
var
  V, N: TVertices;
begin
  MarchingCubes.MarchingCubes(7, Isosurface as IEvaluator, V, N);
  FVertices := V;
  FNormals := N;
end;

procedure TCFDGIsosurface.SetProperty(const PropName: string; Value: Float);
begin
  asm
    @FIsosurface[@PropName] = @Value;
  end;
end;


{ TCFDGExtrudedLine }

constructor TCFDGExtrudedLine.Create;
begin
  FDivisions := DEFAULT_DIVISIONS;
end;

function TCFDGExtrudedLine.GetDivisions: Integer;
var
  Scale: Vector3;
begin
  Scale := MoveEntry.Scale;
  Result := Round((Scale[0]+Scale[1]+Scale[2]) * 8);
  if Result < 3 then Result := 3;
end;

procedure TCFDGExtrudedLine.SetProperty(const PropName: string; Value: Float);
begin
  case PropName of
    'RADIUS': RADIUS := Value;
  end;
/*
  asm
    @Self[@PropName] = @Value;
  end;
*/
end;

procedure TCFDGExtrudedLine.GetVertices(var Vertices, Normals: TVertices);
var
  I, D: Integer;
  t: Float;
  N, V: Vector3;
begin
  D := GetDivisions;
  for I := 0 to D - 1 do
  begin
    t := I / D;
    GetVertex(t, V, N);
    Vertices.Push(V);
    Normals.Push(N);
  end;
end;

procedure TCFDGExtrudedLine.Draw(Context: TCFDGContext);
var
  A, B: TCFDGEntry;
  V, N: TVertices;

  procedure DrawVertices(PosA, QA: Quaternion; SA: Vector3;
    PosB, QB: Quaternion; SB: Vector3);
  var
    I, NextI, L: Integer;
  begin
    L := Length(V);
    for I := 0 to L - 1 do
    begin
      NextI := (I + 1) mod L;

      // triangle mode
      Context.DrawVertex(V[I],N[I], SA, PosA, QA);
      Context.DrawVertex(V[I],N[I], SB, PosB, QB);
      Context.DrawVertex(V[NextI],N[NextI], SA, PosA, QA);

      Context.DrawVertex(V[NextI],N[NextI], SA, PosA, QA);
      Context.DrawVertex(V[NextI],N[NextI], SB, PosB, QB);
      Context.DrawVertex(V[I],N[I], SB, PosB, QB);

      // triangle strip mode
      //Context.DrawVertex(V[I],N[I], SA, PosA, QA);
      //Context.DrawVertex(V[I],N[I], SB, PosB, QB);
      //Context.DrawVertex(V[NextI],N[NextI], SA, PosA, QA);
      //Context.DrawVertex(V[NextI],N[NextI], SB, PosB, QB);
    end;
  end;
begin
  A := MoveEntry;
  B := Context.Entry;
  GetVertices(V, N);
  DrawVertices(A.Pos, A.Q, A.Scale, A.Pos, B.Q, A.Scale);
  DrawVertices(A.Pos, B.Q, A.Scale, B.Pos, B.Q, B.Scale);
  MoveEntry := B;
end;

procedure TCFDGExtrudedLine.Prepare;
begin
end;

{ TCFDGExtrudedLineNGon }

constructor TCFDGExtrudedLineNGon.Create;
begin
  inherited;
  RADIUS := 1.0;
end;

procedure TCFDGExtrudedLineNGon.GetVertex(t: Float; var Vertex: Vector3; var Normal: Vector3);
begin
  t := t * 2 * Pi;
  Normal[0] := Sin(t);
  Normal[1] := Cos(t);
  Normal[2] := 0.0;
  Vertex[0] := Normal[0] * Radius;
  Vertex[1] := Normal[1] * Radius;
  Vertex[2] := 0.0;
end;

{ TCFDGMoveTo }

procedure TCFDGMoveTo.Draw(Context: TCFDGContext);
begin
  MoveEntry := Context.Entry;
end;

procedure TCFDGMoveTo.Prepare;
begin

end;

procedure TCFDGMoveTo.SetProperty(const PropName: String; Value: Float);
begin

end;

{ TCFDGDrawableStore }

function TCFDGDrawableStore.GetDrawable(const DrawableName: string): ICFDGDrawable;
var
  Isosurface: TIsosurface;
  CFDGIsosurface: TCFDGIsosurface;
begin
  case DrawableName of
    'TORUS': Isosurface := TTorusIsosurface.Create;
    'SPHERE': Isosurface := TSphereIsosurface.Create;
    'ROUNDCUBE': Isosurface := TRoundCubeIsosurface.Create;
    'LINETO': exit(TCFDGExtrudedLineNGon.Create);
    'MOVETO': exit(TCFDGMoveTo.Create);
  else
    Result := nil;
    exit;
  end;
  CFDGIsosurface := TCFDGIsosurface.Create;
  CFDGIsosurface.Isosurface := Isosurface;
  Result := CFDGIsosurface;
end;

initialization
  DrawableStore := TCFDGDrawableStore.Create;

finalization
  DrawableStore.Free;

end.
