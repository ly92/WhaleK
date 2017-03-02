//
//  RSADataSigner.m
//  SafepayService
//
//  Created by wenbi on 11-4-11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RSADataSigner.h"
#import "openssl_wrapper.h"
#import "NSDataEx.h"

@implementation RSADataSigner

- (id)initWithPrivateKey:(NSString *)privateKey {
	if (self = [super init]) {
		_privateKey = [privateKey copy];
	}
	return self;
}

- (NSString*)urlEncodedString:(NSString *)string
{
    NSString * encodedString = (__bridge_transfer  NSString*) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL, (__bridge CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8 );
    
    return encodedString;
}


- (NSString *)formatPrivateKey:(NSString *)privateKey {
    const char *pstr = [privateKey UTF8String];
    int len = [privateKey length];
    NSMutableString *result = [NSMutableString string];
    [result appendString:@"-----BEGIN PRIVATE KEY-----\n"];
    int index = 0;
	int count = 0;
    while (index < len) {
        char ch = pstr[index];
		if (ch == '\r' || ch == '\n') {
			++index;
			continue;
		}
        [result appendFormat:@"%c", ch];
        if (++count == 79)
        {
            [result appendString:@"\n"];
			count = 0;
        }
        index++;
    }
    [result appendString:@"\n-----END PRIVATE KEY-----"];
    return result;
}

- (NSString *)algorithmName {
	return @"RSA";
}

//该签名方法仅供参考,外部商户可用自己方法替换
- (NSString *)signString:(NSString *)string {
	
	//在Document文件夹下创建私钥文件
	NSString * signedString = nil;
	NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString *path = [documentPath stringByAppendingPathComponent:@"乾多多App-RSAPrivateKey"];
	
	//
	// 把密钥写入文件
	//
	NSString *formatKey = [self formatPrivateKey:_privateKey];
	[formatKey writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
	
	const char *message = [string cStringUsingEncoding:NSUTF8StringEncoding];
    int messageLength = strlen(message);
    unsigned char *sig = (unsigned char *)malloc(256);
	unsigned int sig_len;
    int ret = rsa_sign_with_private_key_pem((char *)message, messageLength, sig, &sig_len, (char *)[path UTF8String]);
	//签名成功,需要给签名字符串base64编码和UrlEncode,该两个方法也可以根据情况替换为自己函数
    if (ret == 1) {
        NSString * base64String = base64StringFromData([NSData dataWithBytes:sig length:sig_len]);
        NSLog(@"base sign string: %@",base64String);
//		signedString = [self urlEncodedString:base64String];
        signedString = base64String;
    }
	
	free(sig);
    return signedString;
}

/**
 *   dd3bcSobB3e1itRcZQUuAHHriFPhzzlx9KnhQNkMft98exjo+tzgfkdF6PEm/OmEsANcOvdUVToRXJMUz/3K+8CC2tPSJDXuX3kiic5Sqxfd879IFKV+iIVWowe5psgLFll/BEC033okiZMiN8GPSiVpug8xkuL7LU3d10vi2Og=
 */
/**
 *  EZ0GnKZ9N94DvUVGuMEatML90Gm6sPHUJmnmK3QrFtyj41HxZmjWQdQ8nymeuIcS65sMxa35Rmi4laGZTpIW3vNDpkKBprJe5jvDHcZyTeRxnu1ndc7jG6QrBl+V+z7WeeMx4cQPnenMR4yYQKjumzc2MAFfICGRutvGSLrmC+8=
 */

@end
