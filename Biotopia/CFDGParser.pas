unit CFDGParser;

// Quick and dirty CFDG-3D parser
// this should be rewritten at some point using a proper parser generator

{$DEFINE USEISOSURFACE}

interface

uses 
  GLS.Vectors, GLCommon;

const
  DefaultMinSize = 0.03;
  DefaultStackSize = 20000000;

type
  TCFDGNode = class;
  TCFDGProgram = class;
  TCFDGParamList = class;
  TCFDGRuleTable = class;
  TCFDGContext = class;

  ICFDGDrawable = interface
    procedure Draw(Context: TCFDGContext);
    procedure SetProperty(const PropName: string; Value: Float);
    procedure Prepare;
  end;

  ICFDGDrawableStore = interface
    function GetDrawable(const DrawableName: string): ICFDGDrawable;
  end;

  TTokenizer = class
  private
    FInput: String;
    FIndex: Integer;
  protected
    function Advance: Boolean;
    function ReadChar: String;
    function IsNumber: Boolean;
    procedure SkipWhitespace;
    procedure SetInput(const Value: String);
  public
    function ReadString: String;
    function ReadValue: Float;
    procedure Consume(C: String);
    property Input: String read FInput write SetInput;
  end;

  TCFDGParser = class(TTokenizer)
  private
    FAngleMode: string;
    function ReadAngle: Float;
  protected
    procedure ParseParam(Node: TCFDGNode);
    procedure ParseParamList(Node: TCFDGParamList);
    function ParseRecursion(Node: TCFDGNode; Drawables: ICFDGDrawableStore): Boolean;
    procedure ParseRule(Node: TCFDGNode; Drawables: ICFDGDrawableStore);
    procedure ParseStartShape(Node: TCFDGProgram);
    procedure ParseMinSize(Node: TCFDGProgram);
    procedure ParseStackSize(Node: TCFDGProgram);
    function ParseCommand(Node: TCFDGProgram; Drawables: ICFDGDrawableStore): Boolean;
  public
    function Parse(S: String; Drawables: ICFDGDrawableStore): TCFDGProgram;
  end;

//----------------------------------------------------------------------------//

  TCFDGEntry = record
    Pos: Quaternion;
    Q: Quaternion;
    Scale: Vector3;
    Weights: Vector3;
  end;
  TCFDGStack = array of TCFDGEntry;

  TFloatArray = array of Float;

  TCFDGContext = class
  private
    FStack: TCFDGStack;
    FEntry: TCFDGEntry;
    FVertices: TVertices;
    FNormals: TVertices;
    FRadius: TFloatArray;
    FWeights: TVertices;
    FMinSize: Float;
    FMaxStackSize: Integer;
    FMaxObjects: Integer;
    FFrontFacing: Boolean;
    function GetPosition: Quaternion;
    procedure SetPosition(const Pos: Quaternion);
  public
    constructor Create;
    procedure Reset;
    procedure DrawCircle;
    procedure DrawSphere;
    procedure DrawVertices(Vertices: TVertices);
    procedure DrawVertex(Vertex, Normal, S: Vector3; Pos, Q: Quaternion); overload;
    procedure DrawVertex(Vertex, Normal: Vector3); overload;
    function Push: Boolean;
    procedure Pop;
    procedure Scale(V: Vector3);
    procedure Rotate(Q: Quaternion);
    procedure Translate(Q: Quaternion);
    procedure AddWeight(W: Vector3);
    property Position: Quaternion read GetPosition write SetPosition;
    property Vertices: TVertices read FVertices;
    property Normals: TVertices read FNormals;
    property Radius: TFloatArray read FRadius;
    property Weights: TVertices read FWeights;
    property MinSize: Float read FMinSize write FMinSize;
    property MaxStackSize: Integer read FMaxStackSize write FMaxStackSize;
    property MaxObjects: Integer read FMaxObjects write FMaxObjects;
    property FrontFacing: Boolean read FFrontFacing write FFrontFacing;
    property Stack: TCFDGStack read FStack;
    property Entry: TCFDGEntry read FEntry;
  end;

  TCFDGNodeClass = class of TCFDGNode;
  TCFDGNode = class
  protected
    FChildNodes: array of TCFDGNode;
    FParent: TCFDGNode;
  public
    property Parent: TCFDGNode read FParent;
    constructor Create; virtual;
    procedure Prepare(AProgram: TCFDGProgram); virtual;
    procedure Execute(Context: TCFDGContext); virtual;
    function Add(AClass: TCFDGNodeClass): TCFDGNode;
    function SubtreeNodeCount: Integer;
  end;

  TCFDGParamList = class(TCFDGNode)
  protected
    //FMatrix: Matrix3;
    FTranslate: Quaternion;
    FRotate: Quaternion;
    FScale: Vector3;
    FWeights: Vector3;
  public
    constructor Create; override;
    // X = yaw, Y = pitch, Z = roll
    procedure Rotate(X, Y, Z: Float); overload;
    procedure Translate(Q: Quaternion); overload;
    procedure Scale(V: Vector3); overload;
    procedure SetWeights(V: Vector3); overload;
    // flip
    // skew
    // transform
    // hsl, rgb
    procedure Execute(Context: TCFDGContext); override;
    procedure Evaluate(Context: TCFDGContext); virtual;
  end;

  TCFDGRecurse = class(TCFDGParamList)
  private
    FName: String;
    FRule: TCFDGRuleTable;
  public
    procedure Prepare(AProgram: TCFDGProgram); override;
    procedure Evaluate(Context: TCFDGContext); override;
    property Name: String read FName write FName;
  end;

  TCFDGIterator = class(TCFDGParamList)
  private
    FIterations: Integer;
    FRecurse: TCFDGParamList;
  public
    procedure Evaluate(Context: TCFDGContext); override;
    property Recurse: TCFDGParamList read FRecurse write FRecurse;
    property Iterations: Integer read FIterations write FIterations;
  end;

  TCFDGCircle = class(TCFDGParamList)
  public
    procedure Evaluate(Context: TCFDGContext); override;
  end;

  TCFDGDrawable = class(TCFDGParamList)
  private
    FDrawable: ICFDGDrawable;
  public
    procedure Prepare(AProgram: TCFDGProgram); override;
    procedure Evaluate(Context: TCFDGContext); override;
    property Drawable: ICFDGDrawable read FDrawable write FDrawable;
  end;

  TCFDGRule = class(TCFDGNode)
  private
    FName: String;
    FProbability: Float;
  public
    constructor Create; override;
    property Name: String read FName write FName;
    property Probability: Float read FProbability write FProbability;
  end;

  TCFDGRuleArray = array of TCFDGRule;
  TCFDGRuleTable = class
  private
    FRules: TCFDGRuleArray;
    FFrequency: array of Float;
    FName: string;
  public
    function SelectRule: TCFDGRule;
    procedure UpdateFrequencyTable;
    property Name: string read FName write FName;
    property Rules: TCFDGRuleArray read FRules;
  end;

  TCFDGProgram = class(TCFDGNode)
  private
    FStartShape: String;
    FContext: TCFDGContext;
    FRuleTables: array of TCFDGRuleTable;
    FDrawables: ICFDGDrawableStore;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Run;
    function FindRule(const RuleName: String): TCFDGRuleTable;
    property StartShape: String read FStartShape write FStartShape;
    property Context: TCFDGContext read FContext;
    property Drawables: ICFDGDrawableStore read FDrawables write FDrawables;
  end;

function ParseCFDG(Definition: String; Drawables: ICFDGDrawableStore): TCFDGProgram;

var
  MoveEntry: TCFDGEntry;

implementation

uses
  SmartCL.System;

function AngleToDegrees(Angle: Float; Mode: string): Float;
begin
  case Mode of
    'degrees': Result := Angle;
    'arcdegrees': Result := Angle/3600;
    'radians': Result := Angle * 180/Pi;
    'orbits', 'periods', 'revolutions': Result := Angle * 360;
    'frequency': Result := 360 / Angle;
  else
    Result := Angle;
  end;
end;

function ParseCFDG(Definition: String; Drawables: ICFDGDrawableStore): TCFDGProgram;
var
  Parser: TCFDGParser;
begin
  Parser := TCFDGParser.Create;
  try
    Result := Parser.Parse(Definition, Drawables);
    Result.Prepare(Result);
  finally
    Parser.Free;
  end;
end;

function TTokenizer.IsNumber: Boolean;
begin
  SkipWhiteSpace;
  Result := ReadChar in ['0'..'9', '.', '+', '-'];
end;

procedure TTokenizer.SetInput(const Value: String);
begin
  FInput := Value;
  FIndex := 1;
end;

function TTokenizer.Advance: Boolean;
begin
  Inc(FIndex);
  Result := FIndex <= Length(FInput);
end;

function TTokenizer.ReadChar: String;
begin
  Result := FInput[FIndex];
end;

procedure TTokenizer.SkipWhitespace;
begin
  while (ReadChar in [' ', #13, #10, #9]) do
    if not Advance then Exit;
  // strip comment
  if (ReadChar = '/') and Advance and (ReadChar = '/') then
  begin
    while (not (ReadChar in [#13, #10])) do Advance;
    SkipWhiteSpace;
  end;
end;

procedure TTokenizer.Consume(C: String);
begin
  SkipWhiteSpace;
  if ReadChar <> C then
  begin
    WriteLn(ReadChar + ' <> ' + C);
    raise Exception.Create(Format('Expected symbol %s', [C]));
  end;
  Advance;
end;

function TTokenizer.ReadString: String;
var
  X: String;
begin
  SkipWhiteSpace;
  Result := '';
  X := ReadChar;
  while (X in ['a'..'z', 'A'..'Z', '0'..'9']) do
  begin
    Result := Result + X;
    Advance;
    X := ReadChar;
  end;
end;

function TTokenizer.ReadValue: Float;
var
  X: String;
  S: String;
begin
  SkipWhiteSpace;
  S := '';
  X := ReadChar;
  while (X in ['0'..'9','.','+','-']) do
  begin
    S := S + X;
    Advance;
    X := ReadChar;
  end;
  Result := StrToFloat(S);
end;

//----------------------------------------------------------------------------//
procedure TCFDGParser.ParseMinSize(Node: TCFDGProgram);
begin
  Node.Context.MinSize := ReadValue;
end;

procedure TCFDGParser.ParseParam(Node: TCFDGNode);
begin
end;

function IfThen(Cond: Boolean; TrueValue, FalseValue: Float): Float;
begin
  if Cond then
    Result := TrueValue
  else
    Result := FalseValue;
end;

procedure TCFDGParser.ParseParamList(Node: TCFDGParamList);
var
  op: String;
  Value: Float;

  procedure ParseRotate;
  var
    X, Y, Z: Float;
  begin
    X := IfThen(IsNumber, ReadAngle, 0);
    Y := IfThen(IsNumber, ReadAngle, 0);
    Z := IfThen(IsNumber, ReadAngle, 0);
    Node.Rotate(X, Y, Z);
  end;

  procedure ParseRotateX;
  begin
    Node.Rotate(ReadAngle, 0, 0);
  end;

  procedure ParseRotateY;
  begin
    Node.Rotate(0, ReadAngle, 0);
  end;

  procedure ParseRotateZ;
  begin
    Node.Rotate(0, 0, ReadAngle);
  end;


  procedure ParseDown;
  begin
    Node.Rotate(IfThen(IsNumber, ReadValue, -90),0,0);
  end;

  procedure ParseUp;
  begin
    Node.Rotate(IfThen(IsNumber, ReadAngle, 90),0,0);
  end;

  procedure ParseLeft;
  begin
    Node.Rotate(0, IfThen(IsNumber, ReadAngle, -90), 0);
  end;

  procedure ParseRight;
  begin
    Node.Rotate(0, IfThen(IsNumber, ReadAngle, 90), 0);
  end;

  procedure ParseRollLeft;
  begin
    Node.Rotate(0, 0, IfThen(IsNumber, ReadAngle, -90));
  end;

  procedure ParseRollRight;
  begin
    Node.Rotate(0, 0, IfThen(IsNumber, ReadAngle, 90));
  end;

  procedure ParseReverse;
  begin
    //
  end;

  procedure ParseTranslate;
  var
    Q: Quaternion;
  begin
    Q := Quaternion.Identity;
    if IsNumber then Q.X := ReadValue;
    if IsNumber then Q.Y := ReadValue;
    if IsNumber then Q.Z := ReadValue;
    if IsNumber then Q.W := ReadValue;
    Node.Translate(Q);
  end;

  procedure ParseTranslateX;
  var
    Q: Quaternion;
  begin
    Q := Quaternion.Zero;
    Q.X := ReadValue;
    Node.Translate(Q);
  end;

  procedure ParseTranslateY;
  var
    Q: Quaternion;
  begin
    Q := Quaternion.Zero;
    Q.Y := ReadValue;
    Node.Translate(Q);
  end;

  procedure ParseTranslateZ;
  var
    Q: Quaternion;
  begin
    Q := Quaternion.Zero;
    Q.Z := ReadValue;
    Node.Translate(Q);
  end;

  procedure ParseScale;
  var
    V: Vector3;
  begin
    V := Vector3.NullVector;
    if IsNumber then V[0] := ReadValue;
    if IsNumber then V[1] := ReadValue else V[1] := V[0];
    if IsNumber then V[2] := ReadValue else V[2] := V[0];
    Node.Scale(V);
  end;

  procedure ParseWeight1;
  begin
    Node.SetWeights([ReadValue, 0.0, 0.0]);
  end;
  procedure ParseWeight2;
  begin
    Node.SetWeights([0.0, ReadValue, 0.0]);
  end;
  procedure ParseWeight3;
  begin
    Node.SetWeights([0.0, 0.0, ReadValue]);
  end;

begin
  while True do
  begin
    op := ReadString;
    //WriteLn('op = ' + op);
    case op of
      'down': ParseDown;
      'up': ParseUp;
      'left': ParseLeft;
      'right': ParseRight;
      // 'reverse': ParseReverse;
      'r', 'rotate': ParseRotate;
      'rx', 'pitch': ParseRotateX;
      'ry', 'yaw':   ParseRotateY;
      'rz', 'roll':  ParseRotateZ;
      't', 'translate': ParseTranslate;
      's', 'size': ParseScale;
      'x': ParseTranslateX;
      'y': ParseTranslateY;
      'z': ParseTranslateZ;
      'u': ParseWeight1;
      'v': ParseWeight2;
      'w': ParseWeight3;
      //'r', 'g', 'b', 'hue', 'sat', 'bri', 'bri: ReadValue;
      '': exit;
    else
      Value := ReadValue;
      if Node is TCFDGDrawable then
      begin
        TCFDGDrawable(Node).Drawable.SetProperty(UpperCase(op), Value);
      end;
      // unknown operator
      //WriteLn('Unknown operator');
      //raise Exception.Create('Unknown operator');
    end;
  end;
end;

function TCFDGParser.ParseRecursion(Node: TCFDGNode;
  Drawables: ICFDGDrawableStore): Boolean;
var
  Name: String;
  Drawable: ICFDGDrawable;
begin
  if IsNumber then
  begin
    Node := Node.Add(TCFDGIterator);
    TCFDGIterator(Node).Iterations := Round(ReadValue);
    Consume('*');
    Consume('{');
    ParseParamList(TCFDGParamList(Node));
    Consume('}');
    Result := ParseRecursion(Node, Drawables);
    TCFDGIterator(Node).Recurse := Node.FChildNodes[0] as TCFDGParamList;
  end
  else
  begin
    Name := ReadString;
    Result := Name <> '';
    //WriteLn('ParseRecursion ' + Name);
    if Result then
    begin
      Drawable := nil;
      if Assigned(Drawables) then
      begin
        Drawable := Drawables.GetDrawable(Name);
      end;
      if Assigned(Drawable) then
      begin
        Node := Node.Add(TCFDGDrawable);
        TCFDGDrawable(Node).Drawable := Drawable;
      end
      else
      begin
        case Name of
          'CIRCLE':
            begin
              //WriteLn('Node := Node.Add(TCFDGCircle)');
              Node := Node.Add(TCFDGCircle);
            end;
        else
          Node := Node.Add(TCFDGRecurse);
          TCFDGRecurse(Node).Name := Name;
        end;
      end;
      //WriteLn('ParseParamList');
      Consume('{');
      ParseParamList(TCFDGParamList(Node));
      Consume('}');
    end;
  end;
end;

procedure TCFDGParser.ParseRule(Node: TCFDGNode; Drawables: ICFDGDrawableStore);
var
  Rule: TCFDGRule;
begin
  Rule := TCFDGRule(Node.Add(TCFDGRule));
  Rule.Name := ReadString;
  if IsNumber then
    Rule.Probability := ReadValue;
  //WriteLn(Rule.Name + ' Probability = ' + FloatToStr(Rule.Probability));
  Consume('{');
  while ParseRecursion(Rule, Drawables) do;
  Consume('}');
end;

procedure TCFDGParser.ParseStackSize(Node: TCFDGProgram);
begin
  Node.Context.MaxStackSize := Round(ReadValue);
end;

procedure TCFDGParser.ParseStartShape(Node: TCFDGProgram);
begin
  Node.StartShape := ReadString;
end;

function TCFDGParser.ReadAngle: Float;
begin
  Result := AngleToDegrees(ReadValue, FAngleMode);
end;

function TCFDGParser.ParseCommand(Node: TCFDGProgram;
  Drawables: ICFDGDrawableStore): Boolean;
var
  Cmd: String;
begin
  Result := True;
  //WriteLn('ParseCommand');
  Cmd := ReadString;
  //WriteLn('Cmd = ' + Cmd);
  case Cmd of
    'rule': ParseRule(Node, Drawables);
    'startshape': ParseStartShape(Node);
    'minsize': ParseMinSize(Node);
    'stacksize': ParseStackSize(Node);
    'angle': FAngleMode := ReadString;
  else
    Result := False;
  end;
end;

function TCFDGParser.Parse(S: String; Drawables: ICFDGDrawableStore): TCFDGProgram;
begin
  Input := S;
  Result := TCFDGProgram.Create;
  Result.Drawables := Drawables;
  while ParseCommand(Result, Drawables) do;
end;

//----------------------------------------------------------------------------//

function GetRotationMatrix(Rx, Ry, Rz: Float): Matrix3;
var
  Sx, Sy, Sz, Cx, Cy, Cz: Float;
  M: Matrix3;
begin
  Sx := Sin(Rx); Cx := Cos(Rx);
  Sy := Sin(Ry); Cy := Cos(Ry);
  Sz := Sin(Rz); Cz := Cos(Rz);

  M[0] := Cy*Cz; M[1] := -Cx*Sz+Sx*Sy*Cz; M[2] := Sx*Sz+Cx*Sy*Cz;
  M[3] := Cy*Sz; M[4] := Cx*Cz+Sx*Sy*Sz;  M[5] := -Sx*Cz+Cx*Sy*Sz;
  M[6] := -Sy;   M[7] := Sx*Cy;           M[8] := Cx*Cy;
  Result := M;
end;

function Mult(M: Matrix3; V: Vector3): Vector3;
begin
  Result[0] := M[0] * V[0] + M[3] * V[1] + M[6] * V[2];
  Result[1] := M[1] * V[0] + M[4] * V[1] + M[7] * V[2];
  Result[2] := M[2] * V[0] + M[5] * V[1] + M[8] * V[2];
/*
  Result[0] := M[0] * V[0] + M[1] * V[1] + M[2] * V[2];
  Result[1] := M[3] * V[0] + M[4] * V[1] + M[5] * V[2];
  Result[2] := M[6] * V[0] + M[7] * V[1] + M[8] * V[2];
*/
end;

function _DET(a1, a2, a3, b1, b2, b3, c1, c2, c3: Float): Float; overload;
begin
  Result :=
    a1 * (b2 * c3 - b3 * c2) -
    b1 * (a2 * c3 - a3 * c2) +
    c1 * (a2 * b3 - a3 * b2);
end;

function Determinant(const M: Matrix3): Float;
begin
  Result := _DET(M[0], M[1], M[2],
                 M[3], M[4], M[5],
                 M[6], M[7], M[8]);
end;

{ TCFDGContext }

procedure TCFDGContext.AddWeight(W: Vector3);
begin
  FEntry.Weights := FEntry.Weights.Add(W);
end;

constructor TCFDGContext.Create;
begin
  FMinSize := DefaultMinSize;
  FMaxStackSize := DefaultStackSize;
  FFrontFacing := True;
  Reset;
end;

procedure TCFDGContext.Reset;
begin
  FEntry.Pos := Quaternion.Zero;
  FEntry.Q := Quaternion.Identity;
  FEntry.Scale := [1.0, 1.0, 1.0];
  FEntry.Weights := [0.0, 0.0, 0.0];
  FVertices := [];
  FNormals := [];
  FRadius := [];
  FWeights := [];
  FStack := [];
end;

procedure TCFDGContext.DrawSphere;
begin
  DrawCircle;
end;

procedure TCFDGContext.DrawVertex(Vertex, Normal, S: Vector3; Pos, Q: Quaternion);
var
  V, N: Vector3;
begin
  V := Q.Transform(Vertex);
  N := Q.Transform(Normal);
  FVertices.Push(Pos.ToVector3.Add(V.Multiply(S)));
  FNormals.Push(N);
  FRadius.Push(S[0]);
  FWeights.Push(FEntry.Weights);
end;

procedure TCFDGContext.DrawVertex(Vertex, Normal: Vector3);
begin
  DrawVertex(Vertex, Normal, FEntry.Scale, FEntry.Pos, FEntry.Q);
end;

procedure TCFDGContext.DrawCircle;
begin
end;
(*
{$IFDEF USEISOSURFACE}
procedure TCFDGContext.DrawCircle;
var
  I: Integer;
  Q: Quaternion;
  S, V, N: Vector3;
begin
  S := FEntry.S;
  if FrontFacing then
  begin
    for I := 0 to High(SphereVertices) do
    begin
      FVertices.Push(FEntry.Pos.X + SphereVertices[I][0]*S[0]);
      FVertices.Push(FEntry.Pos.Y + SphereVertices[I][1]*S[1]);
      FVertices.Push(FEntry.Pos.Z + SphereVertices[I][2]*S[2]);
      FNormals.Push(SphereNormals[I][0]);
      FNormals.Push(SphereNormals[I][1]);
      FNormals.Push(SphereNormals[I][2]);
     end;
   end
   else
   begin
    Q := FEntry.Q;
    for I := 0 to High(SphereVertices) do
    begin
      V := SphereVertices[I];
      N := SphereNormals[I];
      V := Q.Transform(SphereVertices[I]);
      N := Q.Transform(SphereNormals[I]);
      FVertices.Push(FEntry.Pos.X + V[0]*S[0]);
      FVertices.Push(FEntry.Pos.Y + V[1]*S[1]);
      FVertices.Push(FEntry.Pos.Z + V[2]*S[2]);
      FNormals.Push(N[0]);
      FNormals.Push(N[1]);
      FNormals.Push(N[2]);
     end;
   end;
end;
{$ELSE}
procedure TCFDGContext.DrawCircle;
begin
  FVertices.Push(FEntry.Pos[0]);
  FVertices.Push(FEntry.Pos[1]);
  FVertices.Push(FEntry.Pos[2]);
  FRadius.Push(FEntry.S);
end;
{$ENDIF}
*)

procedure TCFDGContext.DrawVertices(Vertices: TVertices);
begin
end;

function TCFDGContext.GetPosition: Quaternion;
begin
  Result := FEntry.Pos;
end;

procedure TCFDGContext.SetPosition(const Pos: Quaternion);
begin
  FEntry.Pos := Pos;
end;

function TCFDGContext.Push: Boolean;
begin
  Result := (Length(FVertices) < FMaxStackSize) and
    (FEntry.Scale[0]+FEntry.Scale[1]+FEntry.Scale[2] > FMinSize*3);
  if Result then
    FStack.Push(FEntry);
end;

procedure TCFDGContext.Pop;
begin
  FEntry := FStack.Pop;
end;

procedure TCFDGContext.Scale(V: Vector3);
begin
  FEntry.Scale := FEntry.Scale.Multiply(V);
end;

procedure TCFDGContext.Rotate(Q: Quaternion);
begin
  FEntry.Q := FEntry.Q.Multiply(Q);
end;

procedure TCFDGContext.Translate(Q: Quaternion);
begin
  Q.X := Q.X * FEntry.Scale[0];
  Q.Y := Q.Y * FEntry.Scale[1];
  Q.Z := Q.Z * FEntry.Scale[2];
  Q := FEntry.Q.Transform(Q);
  FEntry.pos := FEntry.pos.add(Q);
end;

{ TCFDGNode }

constructor TCFDGNode.Create;
begin
end;

procedure TCFDGNode.Prepare(AProgram: TCFDGProgram);
var
  I: Integer;
begin
  for I := 0 to High(FChildNodes) do
    FChildNodes[I].Prepare(AProgram);
end;

procedure TCFDGNode.Execute(Context: TCFDGContext);
var
  I: Integer;
begin
  //WriteLn(ClassName + '.Execute = ' + inttostr(Length(FChildNodes)));
  for I := 0 to High(FChildNodes) do
    FChildNodes[I].Execute(Context);
end;

function TCFDGNode.Add(AClass: TCFDGNodeClass): TCFDGNode;
begin
  Result := AClass.Create;
  FChildNodes.Push(Result);
end;

function TCFDGNode.SubtreeNodeCount: Integer;
var
  I: Integer;
begin
  Result := 1;
  for I := 0 to High(FChildNodes) do
    Result := Result + FChildNodes[I].SubtreeNodeCount;
end;

{ TCFDGParamList }

constructor TCFDGParamList.Create;
begin
  inherited;
  FTranslate := Quaternion.Zero;
  FRotate := Quaternion.Identity;
  FScale := [1.0, 1.0, 1.0];
end;

procedure TCFDGParamList.Rotate(X, Y, Z: Float);
const
  PIDIV180 = Pi/180;
var
  Q: Quaternion;
begin
  Q := Quaternion.FromEuler(X*PIDIV180, Y*PIDIV180, Z*PIDIV180);
  FRotate := FRotate.Multiply(Q);
end;

procedure TCFDGParamList.Translate(Q: Quaternion);
begin
  Q := FRotate.Transform(Q);
  Q.X := Q.X * FScale[0];
  Q.Y := Q.Y * FScale[1];
  Q.Z := Q.Z * FScale[2];
  FTranslate := FTranslate.Add(Q);
end;

procedure TCFDGParamList.Scale(V: Vector3);
begin
  FScale := FScale.Multiply(V);
end;

procedure TCFDGParamList.SetWeights(V: Vector3);
begin
  FWeights := FWeights.Add(V);
end;

procedure TCFDGParamList.Execute(Context: TCFDGContext);
begin
  if Context.Push then
  begin
    try
      Evaluate(Context);
    finally
      Context.Pop;
    end;
  end;
end;

procedure TCFDGParamList.Evaluate(Context: TCFDGContext);
begin
  Context.Translate(FTranslate);
  Context.Rotate(FRotate);
  Context.Scale(FScale);
  Context.AddWeight(FWeights);
end;

{ TCFDGRecurse }

procedure TCFDGRecurse.Prepare(AProgram: TCFDGProgram);
begin
  FRule := AProgram.FindRule(Name);
end;

procedure TCFDGRecurse.Evaluate(Context: TCFDGContext);
begin
  inherited Evaluate(Context);
  FRule.SelectRule.Execute(Context);
end;

{ TCFDGCircle }

procedure TCFDGCircle.Evaluate(Context: TCFDGContext);
begin
  inherited Evaluate(Context);
  Context.DrawCircle;
end;

{ TCFDGRule }

constructor TCFDGRule.Create;
begin
  inherited;
  FProbability := 1;
end;

{ TCFDGProgram }

constructor TCFDGProgram.Create; 
begin
  inherited;
  FContext := TCFDGContext.Create;
end;

destructor TCFDGProgram.Destroy;
begin
  FContext.Free;
  inherited;
end;

procedure TCFDGProgram.Run;
begin
  FContext.Reset;
  MoveEntry := FContext.Entry;
  FindRule(StartShape).SelectRule.Execute(FContext);
end;

function TCFDGProgram.FindRule(const RuleName: String): TCFDGRuleTable;
var
  I: Integer;
  Node: TCFDGNode;
begin
  for I := 0 to High(FRuleTables) do
    if FRuleTables[I].Name = RuleName then
      exit(FRuleTables[I]);

  Result := TCFDGRuleTable.Create;
  Result.Name := RuleName;
  for I := 0 to High(FChildNodes) do
  begin
    Node := FChildNodes[I];
    if Node is TCFDGRule then
      if TCFDGRule(Node).Name = RuleName then
        Result.Rules.Push(TCFDGRule(Node));
  end;
  FRuleTables.Push(Result);
  Result.UpdateFrequencyTable;
end;

{ TCFDGRuleTable }

function TCFDGRuleTable.SelectRule: TCFDGRule;
var
  Index: Integer;
  X: Float;
begin
  Index := 0;
  if Length(FRules) > 1 then
  begin
    X := Random;
    while (Index <= High(FRules)) and (FFrequency[Index] < X) do Inc(Index);
  end;
  Result := FRules[Index];
end;

procedure TCFDGRuleTable.UpdateFrequencyTable;
var
  I: Integer;
  S, X: Float;
begin
  S := 0;
  for I := 0 to High(FRules) do
    S := S + FRules[I].Probability;
  X := 0;
  for I := 0 to High(FRules) do
  begin
    X := X + FRules[I].Probability;
    FFrequency.Push(X / S);
  end;
end;

{ TCFDGIterator }

procedure TCFDGIterator.Evaluate(Context: TCFDGContext);
var
  I: Integer;
begin
  for I := 0 to FIterations - 1 do
  begin
    //WriteLn(Format('pos = %s',[Context.FEntry.Pos]));
    inherited Evaluate(Context);
    if Context.Push then
    try
      Recurse.Evaluate(Context);
    finally
      Context.Pop;
    end;
  end;
end;

{ TCFDGDrawable }

procedure TCFDGDrawable.Evaluate(Context: TCFDGContext);
begin
  inherited Evaluate(Context);
  FDrawable.Draw(Context);
end;

procedure TCFDGDrawable.Prepare(AProgram: TCFDGProgram);
begin
  FDrawable.Prepare;
end;

end.
