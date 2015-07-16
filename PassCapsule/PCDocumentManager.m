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
#import "PCKeyChainUtils.h"
#import "PCPassword.h"
#import "PCCapsule.h"


#import "PCCloudManager.h"

@interface PCDocumentManager ()

@end

@implementation PCDocumentManager
+(instancetype)sharedDocumentManager{
    static PCDocumentManager *kManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        kManager = [[self alloc] init];
    });
    return kManager;
}

- (PCDocumentDatabase *)documentDatabase{
    if (!_documentDatabase) {
        _documentDatabase = [PCDocumentDatabase sharedDocumentDatabase];
    }
    return _documentDatabase;
}

/**
 *  创建密码库文件
 *
 *  @param documentName   文件名
 *  @param masterPassword 主密码
 *
 *  @return 创建是否成功
 */
- (BOOL)createDocument:(NSString *)databaseName WithMasterPassword:(NSString *)masterPassword{

    [PCPassword setPassword:masterPassword];
    [PCDocumentDatabase setDocumentName:databaseName];
    
    NSString *hashPassword = [PCPassword hashPassword:masterPassword];
    NSLog(@"hashPassword  =  %@",hashPassword);
    NSString *basePassowrd = [[hashPassword dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    [PCKeyChainUtils setString:basePassowrd forKey:KEYCHAIN_PASSWORD andServiceName:KEYCHAIN_PASSWORD_SERVICE];

    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *documentName = [PCDocumentDatabase documentName];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:documentName];
    BOOL fileExists = [fileManager fileExistsAtPath:filePath];
    
    if (fileExists) {
        NSLog(@"file is existed in path = %@",filePath);
        return NO;
    }else{
        DDXMLDocument *capsuleDocument = [self baseTreeWithPassword:masterPassword];

        [[capsuleDocument XMLData] writeToFile:filePath atomically:YES];
        return YES;
    }
    return NO;

}

- (DDXMLDocument *)baseTreeWithPassword:(NSString *) password{
    DDXMLElement *rootElement = [[DDXMLElement alloc] initWithName:CAPSULE_ROOT];
    
    //!!!:测试用，把明文放到xml中，release时一定要记得删除这行
    DDXMLElement *masterKeyElement = [[DDXMLElement alloc] initWithName:@"MasterPassword"];
    [masterKeyElement addAttribute:[DDXMLNode attributeWithName:CAPSULE_ENTRY_ID stringValue:@"0"]];
    [masterKeyElement setStringValue:password];
    [rootElement addChild:masterKeyElement];
    
    NSArray *groups = @[CAPSULE_GROUP_DEFAULT,CAPSULE_GROUP_WEBACCOUNT,CAPSULE_GROUP_EMAIL,CAPSULE_GROUP_CARD];
    for (NSString *groupName in groups) {
        DDXMLElement *groupElement =  [DDXMLElement elementWithName:CAPSULE_GROUP];
        
        [groupElement addAttribute:[DDXMLNode attributeWithName:CAPSULE_GROUP_NAME stringValue:groupName]];
        
        NSArray *aCapsule = @[[DDXMLElement elementWithName:CAPSULE_ENTRY_TITLE stringValue:[NSString stringWithFormat:@"测试 群组:%@",groupName]],
                              [DDXMLElement elementWithName:CAPSULE_ENTRY_ACCOUNT stringValue:@"John Shaw"],
                              [DDXMLElement elementWithName:CAPSULE_ENTRY_PASSWORD stringValue:@"fuck cracker"],
                              [DDXMLElement elementWithName:CAPSULE_ENTRY_SITE stringValue:@"www.zerz.cn"],
                              [DDXMLElement elementWithName:CAPSULE_ENTRY_GROUP stringValue:groupName]];
        
        NSString *entryID = [[PCDocumentDatabase sharedDocumentDatabase] autoIncreaseIDString];
        
        NSArray *attributes = @[[DDXMLNode attributeWithName:CAPSULE_ENTRY_ID stringValue:entryID]];
        [groupElement addChild:[DDXMLElement elementWithName:CAPSULE_ENTRY children:aCapsule attributes:attributes]];
        
        [rootElement addChild:groupElement];
    }

    
    DDXMLDocument *capsuleDocument = [[DDXMLDocument alloc] initWithXMLString:[rootElement XMLString] options:0 error:nil];
    
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:USERDEFAULT_DATABASE_CREATE];
    
    self.documentDatabase.document = capsuleDocument;
    self.documentDatabase.loadDocument = YES;
    return capsuleDocument;
}

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
    NSData *xmlData = [NSData dataWithContentsOfFile:documentPath];
    DDXMLDocument *document = nil;
    if (!self.documentDatabase.isLoad) {
        document = [[DDXMLDocument alloc] initWithData:xmlData options:0 error:nil];
    }
    self.documentDatabase.document = document;
    self.documentDatabase.loadDocument = YES;
    return YES;
}

- (void)preLoadDocunent:(NSData *)xmlData{
    dispatch_queue_t loadDocumentQueue = dispatch_queue_create(LOAD_DOCUMENT_QUEUE, NULL);
    dispatch_async(loadDocumentQueue, ^{
        DDXMLDocument *document = nil;
        if (!self.documentDatabase.isLoad) {
            document = [[DDXMLDocument alloc] initWithData:xmlData options:0 error:nil];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.documentDatabase.document = document;
            self.documentDatabase.loadDocument = YES;
        });

    });
    
}

- (void)parserDocument:(NSData *)xmlData{
    DDXMLDocument *document = nil;
    if (!self.documentDatabase.isLoad) {
        document = [[DDXMLDocument alloc] initWithData:xmlData options:0 error:nil];
        self.documentDatabase.document = document;
        self.documentDatabase.loadDocument = YES;
    } else {
        document = self.documentDatabase.document;
    }
    NSArray *groups = [document nodesForXPath:@"//group" error:nil];
    //遍历group
    for (DDXMLElement *group in groups) {
        PCCapsuleGroup *aGroup = [PCCapsuleGroup new];
        NSString *name = [[group attributeForName:CAPSULE_GROUP_NAME] stringValue];
        NSString *groupCloudID = [[group attributeForName:CAPSULE_CLOUD_ID] stringValue];
        aGroup.groupName = name;
        aGroup.cloudID = groupCloudID;

        NSArray *entries = [group children];
        //遍历group中的每个entry
        for (DDXMLElement *entry in entries) {
            NSArray *aEntry = [entry children];
            PCCapsule *aCapsule = [PCCapsule new];
            
            //entry 的标志符
            NSUInteger capsuleID = [[[entry attributeForName:CAPSULE_ENTRY_ID] stringValue] integerValue];
            aCapsule.capsuleID = capsuleID;
            
            //遍历entry中的每个详细记录
            for (DDXMLNode *e in aEntry) {
                if ([e.name isEqualToString:CAPSULE_ENTRY_TITLE]) {
                    aCapsule.title = e.stringValue;
                }
                if ([e.name isEqualToString:CAPSULE_ENTRY_ACCOUNT]) {
                    aCapsule.account = e.stringValue;
                }
                if ([e.name isEqualToString:CAPSULE_ENTRY_PASSWORD]) {
                    aCapsule.password = e.stringValue;
                }
                if ([e.name isEqualToString:CAPSULE_ENTRY_SITE]) {
                    aCapsule.site = e.stringValue;
                }
                if ([e.name isEqualToString:CAPSULE_ENTRY_ICON]) {
                    aCapsule.iconName = e.stringValue;
                }
                if ([e.name isEqualToString:CAPSULE_ENTRY_GROUP]) {
                    aCapsule.group = e.stringValue;
                }
                if ([e.name isEqualToString:CAPSULE_CLOUD_ID]) {
                    aCapsule.cloudID = e.stringValue;
                }

            }
            //将entry反序列化到capsule对象后，保存到相关集合中
            [self.documentDatabase.entries addObject:aCapsule];
            [aGroup.groupEntries addObject:aCapsule];
        }
        
        //保存group
        [self.documentDatabase.groups addObject:aGroup];
        
    }
    
    AVObject *database = [[PCCloudManager sharedCloudManager] createCloudDatabase:self.documentDatabase];
    NSLog(@"avobjet id %@",[database objectId]);
//    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_PARSER_DONE object:nil];
}

- (void)addNewEntry: (PCCapsule *)entry{
    if (self.documentDatabase.isLoad) {
        
        
        
        DDXMLDocument *document = self.documentDatabase.document;
        NSString *xpath = [NSString stringWithFormat:@"//group[@%@='%@']",
                           CAPSULE_GROUP_NAME,CAPSULE_GROUP_DEFAULT];
        NSArray *results = [document nodesForXPath:xpath error:nil];
        
        if ([results count] == 0) {
            NSLog(@"group name error");
            return;
        }
        
        //TODO:entry id 的设置与获取 － 通过 getter setter 还是 documentDatabase 的 currentID
        DDXMLElement *groupElement = [results firstObject];
        DDXMLElement *newEntry = [DDXMLElement elementWithName:CAPSULE_ENTRY];
        
        //id应该通过documentDatabase 的自动增长方法获取
        entry.capsuleID = [[PCDocumentDatabase sharedDocumentDatabase] autoIncreaseID];
        [newEntry addAttribute:[DDXMLNode attributeWithName:CAPSULE_ENTRY_ID stringValue:entry.idString]];

        
        [newEntry addChild:[DDXMLElement elementWithName:CAPSULE_ENTRY_TITLE stringValue:entry.title]];
        [newEntry addChild:[DDXMLElement elementWithName:CAPSULE_ENTRY_ACCOUNT stringValue:entry.account]];
        [newEntry addChild:[DDXMLElement elementWithName:CAPSULE_ENTRY_PASSWORD stringValue:entry.password]];
        [newEntry addChild:[DDXMLElement elementWithName:CAPSULE_ENTRY_SITE stringValue:entry.site]];
        [newEntry addChild:[DDXMLElement elementWithName:CAPSULE_ENTRY_GROUP stringValue:entry.group]];
        [newEntry addChild:[DDXMLElement elementWithName:CAPSULE_CLOUD_ID stringValue:entry.cloudID]];
        [groupElement addChild:newEntry];
        
        [self.documentDatabase.entries addObject:entry];
        PCCapsuleGroup *group = self.documentDatabase.groups[0];
        [group.groupEntries addObject:entry];
        
        self.documentDatabase.refreshDocument = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SHOULD_RELOAD object:nil];
    }
}

- (void)deleteEntry: (PCCapsule *)entry{
    if (self.documentDatabase.isLoad) {
        DDXMLDocument *document = self.documentDatabase.document;
        NSString *idString = [@(entry.capsuleID) stringValue];
        NSString *xpath = [NSString stringWithFormat:@"//group[@%@='%@']/entry[@%@='%@']"
                           ,CAPSULE_GROUP_NAME,CAPSULE_GROUP_DEFAULT,CAPSULE_ENTRY_ID,idString];
        
        NSArray *results = [document nodesForXPath:xpath error:nil];
        if ([results count] == 0) {
            NSLog(@"group name error");
            return;
        }
        DDXMLElement *deleteElement = [results firstObject];
        DDXMLElement *groupElement = (DDXMLElement *)[deleteElement parent];
        [groupElement removeChildAtIndex:[deleteElement index]];
        
        [self.documentDatabase.entries removeObject:entry];
        PCCapsuleGroup *group = self.documentDatabase.groups[0];
        [group.groupEntries removeObject:entry];
        
        self.documentDatabase.refreshDocument = YES;
//        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SHOULD_RELOAD object:nil];
    } else {
        [self readDocument:[PCDocumentDatabase documentPath] withMasterPassword:@"the method is uncompeleted"];
        [self deleteEntry:entry];
    }
}

- (void)modifyEntry: (PCCapsule *)entry{
    if (self.documentDatabase.isLoad) {
        DDXMLDocument *document = self.documentDatabase.document;
        NSString *idString = [@(entry.capsuleID) stringValue];
        NSString *xpath = [NSString stringWithFormat:@"//group[\"%@\"=\"%@\"]/entry[\"%@\"=\"%@\"]"
                           ,CAPSULE_GROUP_NAME,CAPSULE_GROUP_DEFAULT,CAPSULE_ENTRY_ID,idString];
        NSArray *results = [document nodesForXPath:xpath error:nil];
        if ([results count] == 0) {
            NSLog(@"entry id error");
            return;
        }
        DDXMLElement *modifyEntry = [results firstObject];
        //修改记录id
        [[modifyEntry attributeForName:CAPSULE_ENTRY_ID] setStringValue:entry.idString];
        
        //修改记录内容
        NSArray *aEntry = [modifyEntry children];
        for (DDXMLNode *e in aEntry) {
            if ([e.name isEqualToString:CAPSULE_ENTRY_TITLE]) {
                [e setStringValue:entry.title];
            }
            if ([e.name isEqualToString:CAPSULE_ENTRY_ACCOUNT]) {
                [e setStringValue:entry.account];
            }
            if ([e.name isEqualToString:CAPSULE_ENTRY_PASSWORD]) {
                [e setStringValue:entry.password];
            }
            if ([e.name isEqualToString:CAPSULE_ENTRY_SITE]) {
                [e setStringValue:entry.site];
            }
            if ([e.name isEqualToString:CAPSULE_ENTRY_ICON]) {
                [e setStringValue:entry.iconName];
            }
            if ([e.name isEqualToString:CAPSULE_ENTRY_GROUP]) {
                [e setStringValue:entry.group];
            }
            
        }
        
        self.documentDatabase.refreshDocument = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SHOULD_RELOAD object:nil];
    } else {
        [self readDocument:[PCDocumentDatabase documentPath] withMasterPassword:@"the method is uncompeleted"];
        [self deleteEntry:entry];
    }
}

- (void)saveDocument{
    if (self.documentDatabase.shouldRefresh) {
        DDXMLElement *root = [self.documentDatabase.document rootElement];
        NSString *path = [PCDocumentDatabase documentPath];
        NSLog(@"documentPath = %@",path);
        BOOL wirteSuccess = [[root XMLString] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSLog(@" %@ ",[root XMLString]);
        if (wirteSuccess) {
            self.documentDatabase.refreshDocument = NO;
            NSLog(@"write file success");
        } else {
            NSLog(@"write file fail");
        }
    }
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
