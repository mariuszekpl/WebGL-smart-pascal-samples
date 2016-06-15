unit BinaryFile;

interface

uses
  System.Types, SmartCL.System, SmartCL.Graphics, SmartCL.Controls,
  SmartCL.Components, SmartCL.Buffers, W3C.TypedArray, W3C.Canvas2DContext,
  Khronos.WebGL, GLCommon;

type
  TCustomBinaryData = class
  private
    FImage: TW3Image;
    FOnLoad: TNotifyEvent;
  protected
    FImageData : TW3ImageData;
    procedure ImageLoadHandler(Sender: TObject); virtual;
    procedure ImageDataChanged; virtual; abstract;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure LoadFromURL(aURL: string);

    property OnLoad: TNotifyEvent read FOnLoad write FOnLoad;
    property ImageData: TW3ImageData read FImageData;
    property Image: TW3Image read FImage;
  end;

  TTextureData = class(TCustomBinaryData)
  private
    FTextureID: Integer;
  protected
    procedure ImageDataChanged; override;
    procedure ImageLoadHandler(Sender: TObject); override;
  public
    property TextureID: Integer read FTextureID write FTextureID;
  end;

  TBinaryDataArray = class(TCustomBinaryData)
  private
    FData: TIntArray;
  protected
    procedure ImageDataChanged; override;
  public
    property Data: TIntArray read FData;
  end;

  TBinaryDataBuffer = class(TCustomBinaryData)
  private
    FBuffer: TW3Buffer;
    function GetData(Index: Integer): Integer;
    function GetCount: Integer;
  protected
    procedure ImageDataChanged; override;
  public
    constructor Create; override;
    destructor Destroy; override;

    property Data[Index: Integer]: Integer read GetData;
    property Count: Integer read GetCount;
    property Buffer: TW3Buffer read FBuffer;
  end;

implementation

{ TCustomBinaryData }

constructor TCustomBinaryData.Create;
begin
  FImage := TW3Image.Create(nil);
  FImage.OnLoad := ImageLoadHandler;
end;

destructor TCustomBinaryData.Destroy;
begin
  FImage.Free;
  if Assigned(FImageData) then
    FImageData.Free;
end;

procedure TCustomBinaryData.LoadFromURL(aURL: string);
begin
  FImage.LoadFromURL(aURL);
end;

procedure TCustomBinaryData.ImageLoadHandler(Sender: TObject);
begin
  if (FImage.Handle) and FImage.Ready then
  begin
    FImageData := FImage.toImageData;
    ImageDataChanged;
  end;

  //showmessage('success');
  if Assigned(FOnLoad) then
  begin
    FOnLoad(Self);
  end;
end;


{ TBinaryDataArray }

procedure TBinaryDataArray.ImageDataChanged;
var
  Index: Integer;
  Number: Integer;
  DataIndex: Integer;
  ChunkSize: Integer;
begin
  if (FImageData.Handle.data[0] <> 68) or
    (FImageData.Handle.data[1] <> 65) or
    (FImageData.Handle.data[2] <> 84) or
    (FImageData.Handle.data[3] <> 255) or
    (FImageData.Handle.data[4] <> 65)
   then
    raise Exception.Create('Error');

  ChunkSize := (FImageData.Handle.data[9] shl 24) +
    (FImageData.Handle.data[8] shl 16) + (FImageData.Handle.data[6] shl 8) +
    FImageData.Handle.data[5];

  if FImageData.Width * FImageData.Height > ChunkSize then
    raise Exception.Create('Size mismatch');

  FData.SetLength(ChunkSize);
  Index := 10;
  for DataIndex := 0 to ChunkSize - 1 do
  begin
    Number := FImageData.Handle.data[Index];
    FData[DataIndex] := Number;
    Inc(Index);
    if (Index mod 4 = 3) then
    begin
      if FImageData.Handle.data[Index] <> $FF then
        raise Exception.Create('Alpha Error');
      Inc(Index);
    end;
  end;
end;


{ TBinaryDataBuffer }

constructor TBinaryDataBuffer.Create;
begin
  inherited Create;
  FBuffer := TW3Buffer.Create;
end;

destructor TBinaryDataBuffer.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TBinaryDataBuffer.ImageDataChanged;
var
  Index: Integer;
  Number: Integer;
  DataIndex: Integer;
  ChunkSize: Integer;
  View: TW3ByteBufferView;
begin
  if (FImageData.Handle.data[0] <> 68) or
    (FImageData.Handle.data[1] <> 65) or
    (FImageData.Handle.data[2] <> 84) or
    (FImageData.Handle.data[3] <> 255) or
    (FImageData.Handle.data[4] <> 65)
   then
    raise Exception.Create('Error');
  ChunkSize := (FImageData.Handle.data[9] shl 24) +
    (FImageData.Handle.data[8] shl 16) + (FImageData.Handle.data[6] shl 8) +
    FImageData.Handle.data[5];

  if FImageData.Width * FImageData.Height > ChunkSize then
    raise Exception.Create('Size mismatch');

  FBuffer.Allocate(ChunkSize);
  View := TW3ByteBufferView.Create(FBuffer);
  try
    Index := 10;
    for DataIndex := 0 to ChunkSize - 1 do
    begin
      Number := FImageData.Handle.data[Index];
      View.Data[DataIndex] := Number;
      Inc(Index);
      if (Index mod 4 = 3) then
      begin
        if FImageData.Handle.data[Index] <> $FF then
          raise Exception.Create('Alpha Error');
        Inc(Index);
      end;
    end;
  finally
    View.Free;
  end
end;

function TBinaryDataBuffer.GetData(Index: Integer): Integer;
var
  View: TW3ByteBufferView;
begin
  View := TW3ByteBufferView.Create(FBuffer);
  try
    Result := View.Data[Index];
  finally
    View.Free;
  end
end;

function TBinaryDataBuffer.GetCount: Integer;
begin
  Result := FBuffer.ByteSize;
end;

//----------------------------------------------------------------------------//
{ TTextureData }

procedure TTextureData.ImageDataChanged;
begin
end;

procedure TTextureData.ImageLoadHandler(Sender: TObject);
var
  tex: JWebGLTexture;
  data: JImageData;
begin
  ActiveTexture(TextureID);
  tex := CreateColorTexture(gl.LINEAR);
  data := JImageData(Image.Handle);
  gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, data);
end;

end.
