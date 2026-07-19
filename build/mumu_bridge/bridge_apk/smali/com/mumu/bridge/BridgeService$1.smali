.class Lcom/mumu/bridge/BridgeService$1;
.super Ljava/lang/Object;
.implements Ljava/lang/Runnable;


# annotations
.annotation system Ldalvik/annotation/EnclosingMethod;
    value = Lcom/mumu/bridge/BridgeService;->onCreate()V
.end annotation

.annotation system Ldalvik/annotation/InnerClass;
    accessFlags = 0x0
    name = null
.end annotation


# instance fields
.field final synthetic this$0:Lcom/mumu/bridge/BridgeService;


# direct methods
.method constructor <init>(Lcom/mumu/bridge/BridgeService;)V
    .registers 2

    iput-object p1, p0, Lcom/mumu/bridge/BridgeService$1;->this$0:Lcom/mumu/bridge/BridgeService;
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    return-void
.end method


# virtual methods
.method public run()V
    .registers 2

    iget-object v0, p0, Lcom/mumu/bridge/BridgeService$1;->this$0:Lcom/mumu/bridge/BridgeService;
    invoke-static {v0}, Lcom/mumu/bridge/BridgeService;->access$pulse(Lcom/mumu/bridge/BridgeService;)V
    return-void
.end method
