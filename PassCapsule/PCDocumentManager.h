//
//  PCXMLDocument.h
//  PassCapsule
//
//  Created by 邵建勇 on 15/6/15.
//  Copyright (c) 2015年 John Shaw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PCDocumentDatabase.h"

static char * const LOAD_DOCUMENT_QUEUE = "cn.zerz.passcapsule.loadDocumentQueue";

@interface PCDocumentManager : NSObject

@property (nonatomic, strong) NSMutableArray *Capsules;
@property (nonatomic, strong) NSString *masterPassword;
@property (nonatomic, strong) PCDocumentDatabase *documentDatabase;



- (BOOL)createDocument:(NSString *)databaseName WithMasterPassword:(NSString *)masterPassword;
- (void)parserDocument:(NSData *)xmlData;
- (void)addNewEntry: (PCCapsule *)entry;
- (void)deleteEntry: (PCCapsule *)entry;
- (void)saveDocument;
- (void)preLoadDocunent:(NSData *)xmlData;

+(instancetype)sharedDocumentManager;
/**
 Should create only one instance of class. Should not call init.
 */
- (instancetype)init	__attribute__((unavailable("init is not available in PCDocumentManager, Use sharedDocumentManager"))) NS_DESIGNATED_INITIALIZER;

/**
 Should create only one instance of class. Should not call new.
 */
+ (instancetype)new	__attribute__((unavailable("new is not available in PCDocumentManager, Use sharedDocumentManager")));

@end
