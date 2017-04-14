//
//  ViewController.m
//  SocketWithProtobufClient
//
//  Created by CHENLI on 14/4/2017.
//  Copyright © 2017 CHENLI. All rights reserved.
//

#import "ViewController.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "Socketwithprotobuf.pbobjc.h"

@interface ViewController ()<GCDAsyncSocketDelegate>

@property (weak, nonatomic) IBOutlet UITextField *address;
@property (weak, nonatomic) IBOutlet UITextField *port;
@property (weak, nonatomic) IBOutlet UITextView *infoTextView;
@property (weak, nonatomic) IBOutlet UITextField *messageTF;
@property (weak, nonatomic) IBOutlet UITextField *useridTF;
@property (strong, nonatomic) GCDAsyncSocket *socket;
@property (strong, nonatomic) NSString *UUID;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.UUID = @"thisisanuuid";
    self.useridTF.text = [NSString stringWithFormat:@"%u", arc4random() * 100];
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
}


- (IBAction)getConnected:(id)sender {
    [self.socket connectToHost:self.address.text onPort:self.port.text.integerValue withTimeout:-1 error:nil];
}


- (IBAction)logIn:(id)sender {
    [self showInfo:@"Sending Login request"];
    
    _msg_login_req *login = [[_msg_login_req alloc] init];
    login.userId = (int)[self.useridTF.text integerValue];
    login.userPass = @"123qwe";
    
    NSData *data = [self consolidateData:[login data] protocol:_em_client_message_WsMsgClientLoginReq];
    [self.socket writeData:data withTimeout:-1 tag:0];
}

- (IBAction)sendMsg:(id)sender {
    
    _msg_chat_req *chatReq = [[_msg_chat_req alloc] init];
    chatReq.userId = (int)[self.useridTF.text integerValue];
    chatReq.chatContent = self.messageTF.text;
    
    NSData *data = [self consolidateData:[chatReq data] protocol:_em_client_message_WsMsgClientChatReq];
    [self.socket writeData:data withTimeout:-1 tag:0];
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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self.view endEditing:YES];
}


- (void) showInfo:(NSString *)info{
    self.infoTextView.text = [self.infoTextView.text stringByAppendingFormat:@"%@\n", info];
}


- (void)unConsolidateData:(NSData *)data {
    
    NSData *dataProtocol = [data subdataWithRange:NSMakeRange(78, 4)];
    int protocol = CFSwapInt32HostToLittle(*(int*)([dataProtocol bytes]));
    
    NSData *msgSizeData = [data subdataWithRange:NSMakeRange(82, 4)];
    int msgsize = CFSwapInt32HostToLittle(*(int*)([msgSizeData bytes]));
    
    NSData *msgData = [data subdataWithRange:NSMakeRange(86, msgsize)];
    
    NSLog(@"protocol   %d  ",protocol);
    NSLog(@"msgsize   %d  ",msgsize);

    if(protocol == _em_server_message_WsMsgServerLoginResp){
        
        _msg_login_resp *loginResp = [_msg_login_resp parseFromData:msgData error:nil];
        [self showInfo:[NSString stringWithFormat:@"Login response errorCode : %d ", loginResp.errorCode]];
        
    }else if(protocol == _em_server_message_WsMsgServerLoginNotify){
        
        _msg_login_notify *loginNotify = [_msg_login_notify parseFromData:msgData error:nil];
        [self showInfo:[NSString stringWithFormat:@"User %d Join the chat", loginNotify.userId]];
        
    }else if(protocol == _em_server_message_WsMsgServerChatResp){
        
        _msg_chat_resp *chatResp = [_msg_chat_resp parseFromData:msgData error:nil];
        [self showInfo:[NSString stringWithFormat:@"Send chat message errorCode: %d", chatResp.errorCode]];
        
    }else if(protocol == _em_server_message_WsMsgServerChatNotify){
        
        _msg_chat_notify *chatNotify = [_msg_chat_notify parseFromData:msgData error:nil];
        [self showInfo:[NSString stringWithFormat:@"%d: %@", chatNotify.userId, chatNotify.chatContent]];
        
    }
    
}


#pragma mark - Socket Delegate
- (nullable dispatch_queue_t)newSocketQueueForConnectionFromAddress:(NSData *)address onSocket:(GCDAsyncSocket *)sock{
    return nil;
}
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket{
    
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    
    [self showInfo:[NSString stringWithFormat:@"Connected to : %@  port: %d", host, port]];
    [self.socket readDataWithTimeout:-1 tag:0];
    
}
- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url{
    
}
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    [self unConsolidateData:data];
    [self.socket readDataWithTimeout:-1 tag:0];
}


- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag{
     [self showInfo:[NSString stringWithFormat:@"didReadPartialDataOfLength %lu", tag]];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    [self.socket readDataWithTimeout:-1 tag:0];
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
