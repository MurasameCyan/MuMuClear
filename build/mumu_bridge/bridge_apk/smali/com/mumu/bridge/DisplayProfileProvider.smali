.class public Lcom/mumu/bridge/DisplayProfileProvider;
.super Landroid/content/ContentProvider;


# direct methods
.method public constructor <init>()V
    .locals 0

    invoke-direct {p0}, Landroid/content/ContentProvider;-><init>()V
    return-void
.end method

.method private emptyGridCursor()Landroid/database/Cursor;
    .locals 6

    new-instance v0, Landroid/database/MatrixCursor;
    const/4 v1, 0x4
    new-array v1, v1, [Ljava/lang/String;
    const/4 v2, 0x0
    const-string v3, "row"
    aput-object v3, v1, v2
    const/4 v2, 0x1
    const-string v3, "col"
    aput-object v3, v1, v2
    const/4 v2, 0x2
    const-string v3, "cell_width"
    aput-object v3, v1, v2
    const/4 v2, 0x3
    const-string v3, "cell_height"
    aput-object v3, v1, v2
    invoke-direct {v0, v1}, Landroid/database/MatrixCursor;-><init>([Ljava/lang/String;)V

    const/4 v1, 0x4
    new-array v1, v1, [Ljava/lang/Object;
    const/4 v2, 0x0
    const/4 v3, 0x5
    invoke-static {v3}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;
    move-result-object v3
    aput-object v3, v1, v2
    const/4 v2, 0x1
    const/4 v3, 0x4
    invoke-static {v3}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;
    move-result-object v3
    aput-object v3, v1, v2
    const/4 v2, 0x2
    const/16 v3, 0xc0
    invoke-static {v3}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;
    move-result-object v3
    aput-object v3, v1, v2
    const/4 v2, 0x3
    const/16 v3, 0xd8
    invoke-static {v3}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;
    move-result-object v3
    aput-object v3, v1, v2
    invoke-virtual {v0, v1}, Landroid/database/MatrixCursor;->addRow([Ljava/lang/Object;)V
    return-object v0
.end method


# virtual methods
.method public delete(Landroid/net/Uri;Ljava/lang/String;[Ljava/lang/String;)I
    .locals 1

    const/4 v0, 0x0
    return v0
.end method

.method public getType(Landroid/net/Uri;)Ljava/lang/String;
    .locals 1

    const-string v0, "vnd.android.cursor.dir/app.lawnchair.displayProfileProvider.grid"
    return-object v0
.end method

.method public insert(Landroid/net/Uri;Landroid/content/ContentValues;)Landroid/net/Uri;
    .locals 1

    const/4 v0, 0x0
    return-object v0
.end method

.method public onCreate()Z
    .locals 2

    const-string v0, "MuMuBridge"
    const-string v1, "DisplayProfileProvider onCreate"
    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    const/4 v0, 0x1
    return v0
.end method

.method public query(Landroid/net/Uri;[Ljava/lang/String;Ljava/lang/String;[Ljava/lang/String;Ljava/lang/String;)Landroid/database/Cursor;
    .locals 3

    const-string v0, "MuMuBridge"
    if-eqz p1, :cond_0
    invoke-virtual {p1}, Landroid/net/Uri;->toString()Ljava/lang/String;
    move-result-object v1
    new-instance v2, Ljava/lang/StringBuilder;
    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V
    const-string p2, "DisplayProfileProvider query "
    invoke-virtual {v2, p2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v2, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    :cond_0
    invoke-direct {p0}, Lcom/mumu/bridge/DisplayProfileProvider;->emptyGridCursor()Landroid/database/Cursor;
    move-result-object v0
    return-object v0
.end method

.method public update(Landroid/net/Uri;Landroid/content/ContentValues;Ljava/lang/String;[Ljava/lang/String;)I
    .locals 1

    const/4 v0, 0x0
    return v0
.end method
