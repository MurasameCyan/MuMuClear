.class public Lcom/mumu/bridge/NemuHost;
.super Ljava/lang/Object;


# direct methods
.method public constructor <init>()V
    .registers 1

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    return-void
.end method

.method public static getNemuInitBinder()Landroid/os/IBinder;
    .registers 7

    :try_start_0
    const-string v0, "android.os.ServiceManager"
    invoke-static {v0}, Ljava/lang/Class;->forName(Ljava/lang/String;)Ljava/lang/Class;
    move-result-object v0

    const-string v1, "getService"
    const/4 v2, 0x1
    new-array v3, v2, [Ljava/lang/Class;
    const-class v4, Ljava/lang/String;
    const/4 v5, 0x0
    aput-object v4, v3, v5
    invoke-virtual {v0, v1, v3}, Ljava/lang/Class;->getMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;
    move-result-object v0

    new-array v1, v2, [Ljava/lang/Object;
    const-string v2, "nemuinit"
    aput-object v2, v1, v5
    const/4 v2, 0x0
    invoke-virtual {v0, v2, v1}, Ljava/lang/reflect/Method;->invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v0
    check-cast v0, Landroid/os/IBinder;
    :try_end_24
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_24} :catch_25

    return-object v0

    :catch_25
    move-exception v0
    const-string v1, "MuMuBridge"
    const-string v2, "ServiceManager.getService(nemuinit) failed"
    invoke-static {v1, v2, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    const/4 v0, 0x0
    return-object v0
.end method

.method public static sendMessageToHost(Ljava/lang/String;Ljava/lang/String;)Z
    .registers 8

    if-nez p0, :cond_4
    const-string p0, ""

    :cond_4
    if-nez p1, :cond_8
    const-string p1, ""

    :cond_8
    invoke-static {}, Lcom/mumu/bridge/NemuHost;->getNemuInitBinder()Landroid/os/IBinder;
    move-result-object v0
    if-nez v0, :cond_11
    const/4 v0, 0x0
    return v0

    :cond_11
    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
    move-result-object v1
    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
    move-result-object v2

    :try_start_19
    const-string v3, "android.INemuInit"
    invoke-virtual {v1, v3}, Landroid/os/Parcel;->writeInterfaceToken(Ljava/lang/String;)V
    invoke-virtual {v1, p0}, Landroid/os/Parcel;->writeString(Ljava/lang/String;)V
    invoke-virtual {v1, p1}, Landroid/os/Parcel;->writeString(Ljava/lang/String;)V

    const/4 v3, 0x1
    const/4 v4, 0x0
    invoke-interface {v0, v3, v1, v2, v4}, Landroid/os/IBinder;->transact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
    move-result v0
    invoke-virtual {v2}, Landroid/os/Parcel;->readException()V
    :try_end_2c
    .catch Ljava/lang/Throwable; {:try_start_19 .. :try_end_2c} :catch_34
    .catchall {:try_start_19 .. :try_end_2c} :catchall_32

    invoke-virtual {v2}, Landroid/os/Parcel;->recycle()V
    invoke-virtual {v1}, Landroid/os/Parcel;->recycle()V
    return v0

    :catchall_32
    move-exception v0
    goto :goto_42

    :catch_34
    move-exception v0
    :try_start_35
    const-string v3, "MuMuBridge"
    const-string v4, "sendMessageToHost failed"
    invoke-static {v3, v4, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    :try_end_3c
    .catchall {:try_start_35 .. :try_end_3c} :catchall_32

    invoke-virtual {v2}, Landroid/os/Parcel;->recycle()V
    invoke-virtual {v1}, Landroid/os/Parcel;->recycle()V
    const/4 v0, 0x0
    return v0

    :goto_42
    invoke-virtual {v2}, Landroid/os/Parcel;->recycle()V
    invoke-virtual {v1}, Landroid/os/Parcel;->recycle()V
    throw v0
.end method

.method public static sendJsonToHost(Ljava/lang/String;)Z
    .registers 2

    const-string v0, "rom_to_shell"
    invoke-static {v0, p0}, Lcom/mumu/bridge/NemuHost;->sendMessageToHost(Ljava/lang/String;Ljava/lang/String;)Z
    move-result p0
    return p0
.end method

.method public static broadcastLifecycle(Landroid/content/Context;Ljava/lang/String;)V
    .registers 4

    if-eqz p0, :cond_2c
    if-nez p1, :cond_6
    goto :goto_2c

    :cond_6
    new-instance v0, Landroid/content/Intent;
    const-string v1, "com.mumu.LAUNCHER_LIFECYCLE"
    invoke-direct {v0, v1}, Landroid/content/Intent;-><init>(Ljava/lang/String;)V

    const-string v1, "mumu_extra_lifecycle"
    invoke-virtual {v0, v1, p1}, Landroid/content/Intent;->putExtra(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;

    const-string v1, "com.mumu.store"
    invoke-virtual {v0, v1}, Landroid/content/Intent;->setPackage(Ljava/lang/String;)Landroid/content/Intent;

    const/16 v1, 0x20
    invoke-virtual {v0, v1}, Landroid/content/Intent;->addFlags(I)Landroid/content/Intent;

    :try_start_1e
    invoke-virtual {p0, v0}, Landroid/content/Context;->sendBroadcast(Landroid/content/Intent;)V
    :try_end_21
    .catch Ljava/lang/Throwable; {:try_start_1e .. :try_end_21} :catch_22

    return-void

    :catch_22
    move-exception p0
    const-string p1, "MuMuBridge"
    const-string v0, "broadcastLifecycle failed"
    invoke-static {p1, v0, p0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    :cond_2c
    :goto_2c
    return-void
.end method

.method public static notifyHomeReady(Landroid/content/Context;)V
    .registers 5

    const-string v0, "ON_CREATE"
    invoke-static {p0, v0}, Lcom/mumu/bridge/NemuHost;->broadcastLifecycle(Landroid/content/Context;Ljava/lang/String;)V

    const-string v0, "ON_RESUME"
    invoke-static {p0, v0}, Lcom/mumu/bridge/NemuHost;->broadcastLifecycle(Landroid/content/Context;Ljava/lang/String;)V

    new-instance v0, Ljava/lang/StringBuilder;
    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V
    const-string v1, "{\"method\":\"player/channel\",\"params\":{\"sender\":\"com.mumu.bridge\",\"action\":\"launcher_ready\",\"package\":\"app.lawnchair\",\"ts\":"
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-static {}, Ljava/lang/System;->currentTimeMillis()J
    move-result-wide v1
    invoke-virtual {v0, v1, v2}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    const-string v1, "}}"
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0

    invoke-static {v0}, Lcom/mumu/bridge/NemuHost;->sendJsonToHost(Ljava/lang/String;)Z
    move-result v0

    const-string v1, "MuMuBridge"
    new-instance v2, Ljava/lang/StringBuilder;
    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V
    const-string v3, "notifyHomeReady binderOk="
    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v2, v0}, Ljava/lang/StringBuilder;->append(Z)Ljava/lang/StringBuilder;
    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-static {v1, v0}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-void
.end method
