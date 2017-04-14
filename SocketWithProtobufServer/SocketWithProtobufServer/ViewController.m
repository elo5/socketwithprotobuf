//
//  ViewController.m
//  SocketWithProtobufServer
//
//  Created by CHENLI on 14/4/2017.
//  Copyright © 2017 CHENLI. All rights reserved.
//

#import "ViewController.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "Socketwithprotobuf.pbobjc.h"

@interface ViewController ()<GCDAsyncSocketDelegate>

@property (strong, nonatomic) GCDAsyncSocket *socket;
@property (strong, nonatomic)NSMutableArray *clientSockets;

@property (weak, nonatomic) IBOutlet UITextField *port;
@property (weak, nonatomic) IBOutlet UITextField *msgTF;
@property (weak, nonatomic) IBOutlet UITextView *infoTextView;

@property (strong, nonatomic) NSString *UUID;

@end

@implementation ViewController

- (NSMutableArray *)clientSockets{
    if(_clientSockets == nil){
        _clientSockets = [NSMutableArray array];
    }
    return _clientSockets;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.UUID = @"thisisanuuid";
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
}

- (IBAction)startToListen:(id)sender {
    NSError *error = nil;
    BOOL result = [self.socket acceptOnPort:self.port.text.integerValue error:&error];
    if (result && error == nil) {
        [self showInfo:[NSString stringWithFormat:@"Listening on port : %@ ", self.port.text]];
    }else{
        [self showInfo:[NSString stringWithFormat:@"Listening on port : %@ failed(%@), try again!", self.port.text,error]];
    }
}

- (IBAction)sendMsg:(id)sender {
    
     [self sendChatNotify:self.msgTF.text userid:10891];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) showInfo:(NSString *)info{
    self.infoTextView.text = [self.infoTextView.text stringByAppendingFormat:@"%@\n", info];
}

- (void)unConsolidateData:(NSData *)data withSocket:(GCDAsyncSocket *)sock{
    
    NSData *dataProtocol = [data subdataWithRange:NSMakeRange(78, 4)];
    int protocol = CFSwapInt32HostToLittle(*(int*)([dataProtocol bytes]));
    
    NSData *msgSizeData = [data subdataWithRange:NSMakeRange(82, 4)];
    int msgsize = CFSwapInt32HostToLittle(*(int*)([msgSizeData bytes]));
    
    NSData *msgData = [data subdataWithRange:NSMakeRange(86, msgsize)];
    
    NSLog(@"protocol   %d  ",protocol);
    NSLog(@"msgsize   %d  ",msgsize);
    
    if(protocol == _em_client_message_WsMsgClientLoginReq){
        
        _msg_login_req *req = [_msg_login_req parseFromData:msgData error:nil];
        [self showInfo:[NSString stringWithFormat:@"Login req userId:%d  userPass: %@", req.userId, req.userPass]];
        
        _msg_login_resp *resp = [[_msg_login_resp alloc] init];
        resp.errorCode = _en_error_type_LoginSuccess;
        NSData *data = [self consolidateData:[resp data] protocol:_em_server_message_WsMsgServerLoginResp];

        for(GCDAsyncSocket *socket in self.clientSockets){
            
            if([sock.connectedHost isEqualToString:socket.connectedHost]){
                [socket writeData:data withTimeout:-1 tag:0];
            }
        }
        
        [self sendLoginNotify:req.userId];
        
    }else if(protocol == _em_client_message_WsMsgClientChatReq){
        
        _msg_chat_req *chatReq = [_msg_chat_req parseFromData:msgData error:nil];
        
        _msg_chat_resp *chatresp = [[_msg_chat_resp alloc] init];
        chatresp.errorCode = _en_error_type_ChatSuccess;
        NSData *data = [self consolidateData:[chatresp data] protocol:_em_server_message_WsMsgServerChatResp];
        
        for(GCDAsyncSocket *socket in self.clientSockets){
            
            if([sock.connectedHost isEqualToString:socket.connectedHost]){
                [socket writeData:data withTimeout:-1 tag:0];
            }
        }
        
        [self sendChatNotify:chatReq.chatContent userid:chatReq.userId];
    }
}

- (void)sendLoginNotify:(int)userid{
    
    _msg_login_notify *notify = [[_msg_login_notify alloc] init];
    notify.userId = userid;
    NSData *data = [self consolidateData:[notify data] protocol:_em_server_message_WsMsgServerLoginNotify];
    
    for(GCDAsyncSocket *socket in self.clientSockets){
        [socket writeData:data withTimeout:-1 tag:0];
    }
}

- (void)sendChatNotify:(NSString *)msg userid:(int)userid{
    
    _msg_chat_notify *chatNotify = [[_msg_chat_notify alloc] init];
    chatNotify.chatContent = msg;
    chatNotify.userId = userid;
    NSData *data = [self consolidateData:[chatNotify data] protocol:_em_server_message_WsMsgServerChatNotify];
    
    for(GCDAsyncSocket *socket in self.clientSockets){
        [socket writeData:data withTimeout:-1 tag:0];
    }
}

- (NSData *)consolidateData:(NSData *)data protocol:(int)protocol{
    
    NSMutableData *allData = [NSMutableData data];
    
    short first = 0xEA;
    int msgSize = (int)data.length;
    short len = msgSize + 82;
    
    [allData appendData:[NSData dataWithBytes:&first length:sizeof(first)]];
    [allData appendData:[NSData dataWithBytes:&len length:sizeof(len)]];
    
    NSData *uuidData = [self.UUID dataUsingEncoding:NSUTF8StringEncoding];
    [allData appendData:uuidData];
    int leftZeroDataLen = 64 - (int)uuidData.length;
    for(int i = 0; i< leftZeroDataLen; i++){
        [allData appendData:[NSData dataWithBytes:&first length:1]];
    }
    
    int zerodata = 0;
    [allData appendData:[NSData dataWithBytes:&zerodata length:sizeof(zerodata)]];
    [allData appendData:[NSData dataWithBytes:&zerodata length:sizeof(zerodata)]];
    [allData appendData:[NSData dataWithBytes:&first length:sizeof(first)]];
    
    [allData appendData:[NSData dataWithBytes:&protocol length:sizeof(protocol)]];
    [allData appendData:[NSData dataWithBytes:&msgSize length:sizeof(msgSize)]];
    
    [allData appendData:data];
    
    return  allData;
}

#pragma mark - Socket Delegate
- (nullable dispatch_queue_t)newSocketQueueForConnectionFromAddress:(NSData *)address onSocket:(GCDAsyncSocket *)sock{
    return nil;
}
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket{
    [self.clientSockets addObject:newSocket];
     [self showInfo:[NSString stringWithFormat:@"didAcceptNewSocket newSocket host: %@  newSocket port: %d ", newSocket.connectedHost, newSocket.connectedPort ]];
    
    for(GCDAsyncSocket *socket in self.clientSockets){
        [socket readDataWithTimeout:-1 tag:0];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    
    [self showInfo:[NSString stringWithFormat:@"Connected to : %@  port: %d", host, port]];
    [self.socket readDataWithTimeout:-1 tag:0];
    
}
- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url{
    
}
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    
    [self unConsolidateData:data withSocket:sock];
    
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    [self.socket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag{
    [self showInfo:[NSString stringWithFormat:@"didReadPartialDataOfLength %lu", tag]];
}

- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag{
    [self showInfo:[NSString stringWithFormat:@"didWritePartialDataOfLength %lu", tag]];
}

//- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
//                 elapsed:(NSTimeInterval)elapsed
//               bytesDone:(NSUInteger)length;


//- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
//                 elapsed:(NSTimeInterval)elapsed
//               bytesDone:(NSUInteger)length;


- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock{
    [self showInfo:@"socketDidCloseReadStream"];
}
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err{
    [self showInfo:[NSString stringWithFormat:@"socketDidDisconnect withError  %@", err]];
}
- (void)socketDidSecure:(GCDAsyncSocket *)sock{
    
}

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust
completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler{
    
}

@end
