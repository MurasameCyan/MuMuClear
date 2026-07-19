.class public Lcom/mumu/bridge/MuMuNotificationReceiver;
.super Landroid/content/BroadcastReceiver;


# static fields
.field private static final TAG:Ljava/lang/String; = "MuMuBridge"


# direct methods
.method public constructor <init>()V
    .registers 1

    invoke-direct {p0}, Landroid/content/BroadcastReceiver;-><init>()V
    return-void
.end method


# virtual methods
.method public onReceive(Landroid/content/Context;Landroid/content/Intent;)V
    .registers 8

    if-nez p1, :cond_0
    return-void

    :cond_0
    const-string v0, "MuMuBridge"
    if-nez p2, :cond_1
    const-string v1, "MuMuNotificationReceiver null intent"
    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-void

    :cond_1
    invoke-virtual {p2}, Landroid/content/Intent;->getAction()Ljava/lang/String;
    move-result-object v1
    const-string v2, "mumu_extra_notification_id"
    const/4 v3, -0x1
    invoke-virtual {p2, v2, v3}, Landroid/content/Intent;->getIntExtra(Ljava/lang/String;I)I
    move-result v2

    new-instance v3, Ljava/lang/StringBuilder;
    invoke-direct {v3}, Ljava/lang/StringBuilder;-><init>()V
    const-string v4, "MuMuNotificationReceiver action="
    invoke-virtual {v3, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v3, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, " id="
    invoke-virtual {v3, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v3, v2}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v3}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    # best-effort cancel if id present
    const/4 v1, -0x1
    if-eq v2, v1, :cond_2
    const-string v1, "notification"
    invoke-virtual {p1, v1}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;
    move-result-object v1
    instance-of v3, v1, Landroid/app/NotificationManager;
    if-eqz v3, :cond_2
    check-cast v1, Landroid/app/NotificationManager;
    invoke-virtual {v1, v2}, Landroid/app/NotificationManager;->cancel(I)V

    :cond_2
    return-void
.end method
