//
//  PCXMLDocument.m
//  PassCapsule
//
//  Created by 邵建勇 on 15/6/15.
//  Copyright (c) 2015年 John Shaw. All rights reserved.
//

#import "PCDocumentManager.h"
#import "RNEncryptor.h"
#import "RNDecryptor.h"
#import "DDXML.h"
#import "PCKeyChainCapsule.h"
#import "PCConfiguration.h"
#import "PCPassword.h"

@interface PCDocumentManager ()

@property (nonatomic,strong) NSData *testEncryptData;

@end

@implementation PCDocumentManager

- (BOOL)createDocument:(NSString *)documentName WithMasterPassword:(NSString *)masterPassword{
    
    [[NSUserDefaults standardUserDefaults] setObject:documentName forKey:@"documentName"];
    
    NSData *randomData = [PCPassword generateSaltOfSize:64];
    NSString *baseKey = [randomData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    [PCKeyChainCapsule setString:baseKey forKey:KEYCHAIN_KEY andServiceName:KEYCHAIN_KEY_SERVICE];
    NSLog(@"base64key  =  %@",baseKey);
    
    
    NSString *hashPassword = [PCPassword hashPassword:masterPassword];
    NSLog(@"hashPassword  =  %@",hashPassword);
    NSString *basePassowrd = [[hashPassword dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    [PCKeyChainCapsule setString:basePassowrd forKey:KEYCHAIN_PASSWORD andServiceName:KEYCHAIN_PASSWORD_SERVICE];

    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:documentName];
    
    [PCConfiguration setDocumentPath:filePath];
    
    BOOL fileExists = [fileManager fileExistsAtPath:filePath];
    if (fileExists) {
        NSLog(@"file is existed in path = %@",filePath);
        return NO;
    }else{
        DDXMLElement *rootElement = [[DDXMLElement alloc] initWithName:@"Capsules"];
        DDXMLElement *masterKeyElement = [[DDXMLElement alloc] initWithName:@"MasterPassword"];
        [masterKeyElement addAttribute:[DDXMLNode attributeWithName:@"id" stringValue:@"0"]];
        [masterKeyElement setStringValue:basePassowrd];
        [rootElement addChild:masterKeyElement];
        
//        self.testEncryptData = [[NSData alloc] initWithBase64EncodedString:[masterKeyElement stringValue] options:0];
        
        DDXMLDocument *capsuleDocument = [[DDXMLDocument alloc] initWithXMLString:[rootElement XMLString] options:0 error:nil];
        
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"isCreateDatabase"];
        
        [[capsuleDocument XMLData] writeToFile:filePath atomically:YES];
        
        return YES;
        
    }
    return NO;
//    NSLog(@"file path = %@",filePath);
//    [self testDecypyt];
}

//- (void)creatKey:(NSString *)encryptionText{
//    NSString *randomKey = [self randomStringWithLength:32];
//    [PCKeyChainCapsule setString:randomKey forKey:@"MasterKey" andServiceName:KEYCHAIN_KEY_SERVICE];
//    
//}

- (BOOL)readDocument:(NSString *)documentPath withMasterPassword:(NSString *)masterPassword{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL fileExists = [fileManager fileExistsAtPath:documentPath];
    if (!fileExists) {
        NSLog(@"file not exits");
        return NO;
    }
    if ([masterPassword length] == 0) {
        NSLog(@"password is empty");
        return NO;
    }
    
    
    return YES;
}


//改用 apple security框架中的 SecRandom
//- (void)testDecypyt{
//    NSString *key = [PCKeyChainCapsule stringForKey:@"masterKey" andServiceName:KEYCHAIN_KEY_SERVICE];
//    NSData *decryptData = [RNDecryptor decryptData:self.testEncryptData
//                                      withPassword:key
//                                             error:nil];
//    NSString *decryptString = [[NSString alloc] initWithData:decryptData encoding:NSUTF8StringEncoding];
//    NSLog(@"decrypt string is %@",decryptString);
//}
//
//
//NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789~!@#$%^&*()_+`-=[]\\;',./{}|:\"<>?";
//
//- (NSString *) randomStringWithLength: (int)len{
//    
//    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
//    
//    for (int i=0; i<len; i++) {
//        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform([letters length])]];
//    }
//    
//    return randomString;
//    
////另一种方案
////    char data[NUMBER_OF_CHARS];
////    for (int x=0;x<NUMBER_OF_CHARS;data[x++] = (char)('A' + (arc4random_uniform(26))));
////    return [[NSString alloc] initWithBytes:data length:NUMBER_OF_CHARS encoding:NSUTF8StringEncoding];
////
////
//
////第三种方案
////    NSTimeInterval  today = [[NSDate date] timeIntervalSince1970];
////    NSString *intervalString = [NSString stringWithFormat:@"%f", today];
////    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[intervalString doubleValue]];
////    
////    NSDateFormatter *formatter=[[NSDateFormatter alloc]init];
////    [formatter setDateFormat:@"yyyyMMddhhmm"];
////    NSString *strdate=[formatter stringFromDate:date];
//}


@end
