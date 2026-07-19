.class public Lcom/mumu/bridge/BridgeApp;
.super Landroid/app/Application;


# direct methods
.method public constructor <init>()V
    .registers 1

    invoke-direct {p0}, Landroid/app/Application;-><init>()V
    return-void
.end method


# virtual methods
.method public onCreate()V
    .locals 4

    invoke-super {p0}, Landroid/app/Application;->onCreate()V

    const-string v0, "MuMuBridge"
    const-string v1, "BridgeApp.onCreate"
    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    new-instance v0, Landroid/content/Intent;
    const-class v1, Lcom/mumu/bridge/BridgeService;
    invoke-direct {v0, p0, v1}, Landroid/content/Intent;-><init>(Landroid/content/Context;Ljava/lang/Class;)V

    :try_start_0
    sget v1, Landroid/os/Build$VERSION;->SDK_INT:I
    const/16 v2, 0x1a
    if-lt v1, v2, :cond_0
    invoke-virtual {p0, v0}, Landroid/content/Context;->startForegroundService(Landroid/content/Intent;)Landroid/content/ComponentName;
    goto :goto_0

    :cond_0
    invoke-virtual {p0, v0}, Landroid/content/Context;->startService(Landroid/content/Intent;)Landroid/content/ComponentName;
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    :goto_0
    goto :goto_1

    :catch_0
    move-exception v0
    const-string v1, "MuMuBridge"
    const-string v2, "start BridgeService failed"
    invoke-static {v1, v2, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    :goto_1
    invoke-static {p0}, Lcom/mumu/bridge/NemuHost;->notifyHomeReady(Landroid/content/Context;)V
    return-void
.end method
