.class public Lcom/mumu/bridge/BridgeService;
.super Landroid/app/Service;


# static fields
.field private static final CHANNEL_ID:Ljava/lang/String; = "mumu_bridge"

.field private static final NOTIFY_ID:I = 0x2b67


# instance fields
.field private mHandler:Landroid/os/Handler;

.field private mPulse:Ljava/lang/Runnable;


# direct methods
.method public constructor <init>()V
    .registers 1

    invoke-direct {p0}, Landroid/app/Service;-><init>()V
    return-void
.end method

.method static synthetic access$pulse(Lcom/mumu/bridge/BridgeService;)V
    .registers 1

    invoke-direct {p0}, Lcom/mumu/bridge/BridgeService;->pulse()V
    return-void
.end method

.method private ensureChannel()V
    .locals 5

    sget v0, Landroid/os/Build$VERSION;->SDK_INT:I
    const/16 v1, 0x1a
    if-ge v0, v1, :cond_0
    return-void

    :cond_0
    const-string v0, "notification"
    invoke-virtual {p0, v0}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;
    move-result-object v0
    check-cast v0, Landroid/app/NotificationManager;
    if-nez v0, :cond_1
    return-void

    :cond_1
    new-instance v1, Landroid/app/NotificationChannel;
    const-string v2, "mumu_bridge"
    const-string v3, "MuMu Bridge"
    const/4 v4, 0x2
    invoke-direct {v1, v2, v3, v4}, Landroid/app/NotificationChannel;-><init>(Ljava/lang/String;Ljava/lang/CharSequence;I)V
    const/4 v2, 0x0
    invoke-virtual {v1, v2}, Landroid/app/NotificationChannel;->setShowBadge(Z)V
    invoke-virtual {v0, v1}, Landroid/app/NotificationManager;->createNotificationChannel(Landroid/app/NotificationChannel;)V
    return-void
.end method

.method private buildNotification()Landroid/app/Notification;
    .locals 3

    invoke-direct {p0}, Lcom/mumu/bridge/BridgeService;->ensureChannel()V

    new-instance v0, Landroid/app/Notification$Builder;
    const-string v1, "mumu_bridge"
    invoke-direct {v0, p0, v1}, Landroid/app/Notification$Builder;-><init>(Landroid/content/Context;Ljava/lang/String;)V

    const-string v1, "MuMu 远程桥接"
    invoke-virtual {v0, v1}, Landroid/app/Notification$Builder;->setContentTitle(Ljava/lang/CharSequence;)Landroid/app/Notification$Builder;

    const-string v1, "保持与 host 通信（无广告桌面）"
    invoke-virtual {v0, v1}, Landroid/app/Notification$Builder;->setContentText(Ljava/lang/CharSequence;)Landroid/app/Notification$Builder;

    const v1, 0x108009b
    invoke-virtual {v0, v1}, Landroid/app/Notification$Builder;->setSmallIcon(I)Landroid/app/Notification$Builder;

    const/4 v1, 0x1
    invoke-virtual {v0, v1}, Landroid/app/Notification$Builder;->setOngoing(Z)Landroid/app/Notification$Builder;

    const/4 v1, -0x1
    invoke-virtual {v0, v1}, Landroid/app/Notification$Builder;->setPriority(I)Landroid/app/Notification$Builder;

    invoke-virtual {v0}, Landroid/app/Notification$Builder;->build()Landroid/app/Notification;
    move-result-object v0
    return-object v0
.end method

.method private pulse()V
    .locals 4

    invoke-static {p0}, Lcom/mumu/bridge/NemuHost;->notifyHomeReady(Landroid/content/Context;)V

    iget-object v0, p0, Lcom/mumu/bridge/BridgeService;->mHandler:Landroid/os/Handler;
    if-eqz v0, :cond_0
    iget-object v1, p0, Lcom/mumu/bridge/BridgeService;->mPulse:Ljava/lang/Runnable;
    if-eqz v1, :cond_0
    const-wide/32 v2, 0x2bf20
    invoke-virtual {v0, v1, v2, v3}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z

    :cond_0
    return-void
.end method


# virtual methods
.method public onBind(Landroid/content/Intent;)Landroid/os/IBinder;
    .locals 1

    const/4 v0, 0x0
    return-object v0
.end method

.method public onCreate()V
    .locals 2

    invoke-super {p0}, Landroid/app/Service;->onCreate()V

    new-instance v0, Landroid/os/Handler;
    invoke-static {}, Landroid/os/Looper;->getMainLooper()Landroid/os/Looper;
    move-result-object v1
    invoke-direct {v0, v1}, Landroid/os/Handler;-><init>(Landroid/os/Looper;)V
    iput-object v0, p0, Lcom/mumu/bridge/BridgeService;->mHandler:Landroid/os/Handler;

    new-instance v0, Lcom/mumu/bridge/BridgeService$1;
    invoke-direct {v0, p0}, Lcom/mumu/bridge/BridgeService$1;-><init>(Lcom/mumu/bridge/BridgeService;)V
    iput-object v0, p0, Lcom/mumu/bridge/BridgeService;->mPulse:Ljava/lang/Runnable;
    return-void
.end method

.method public onStartCommand(Landroid/content/Intent;II)I
    .locals 2

    :try_start_0
    invoke-direct {p0}, Lcom/mumu/bridge/BridgeService;->buildNotification()Landroid/app/Notification;
    move-result-object v0
    const/16 v1, 0x2b67
    invoke-virtual {p0, v1, v0}, Landroid/app/Service;->startForeground(ILandroid/app/Notification;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    goto :goto_0

    :catch_0
    move-exception v0
    const-string v1, "MuMuBridge"
    const-string p1, "startForeground failed"
    invoke-static {v1, p1, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    :goto_0
    invoke-direct {p0}, Lcom/mumu/bridge/BridgeService;->pulse()V
    const/4 v0, 0x1
    return v0
.end method

.method public onDestroy()V
    .locals 2

    iget-object v0, p0, Lcom/mumu/bridge/BridgeService;->mHandler:Landroid/os/Handler;
    if-eqz v0, :cond_0
    iget-object v1, p0, Lcom/mumu/bridge/BridgeService;->mPulse:Ljava/lang/Runnable;
    if-eqz v1, :cond_0
    invoke-virtual {v0, v1}, Landroid/os/Handler;->removeCallbacks(Ljava/lang/Runnable;)V

    :cond_0
    invoke-super {p0}, Landroid/app/Service;->onDestroy()V
    return-void
.end method
