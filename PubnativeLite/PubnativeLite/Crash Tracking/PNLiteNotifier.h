//
//  Copyright © 2018 PubNative. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <Foundation/Foundation.h>

#import "PNLiteConfiguration.h"
#import "PNLiteMetaData.h"

@class PNLiteConnectivity;

@interface PNLiteNotifier : NSObject <PNLiteMetaDataDelegate>

@property(nonatomic, readwrite, retain)
    PNLiteConfiguration *_Nullable configuration;
@property(nonatomic, readwrite, retain) PNLiteMetaData *_Nonnull state;
@property(nonatomic, readwrite, retain) NSDictionary *_Nonnull details;
@property(nonatomic, readwrite, retain) NSLock *_Nonnull metaDataLock;

@property(nonatomic) PNLiteConnectivity *_Nonnull networkReachable;

- (instancetype _Nonnull)initWithConfiguration:
    (PNLiteConfiguration *_Nonnull)configuration;
- (void)start;

- (void)startSession;

/**
 *  Notify PNLite of an exception
 *
 *  @param exception the exception
 *  @param block     Configuration block for adding additional report
 * information
 */
- (void)notifyException:(NSException *_Nonnull)exception
                  block:(PNLiteNotifyBlock _Nullable)block;

/**
 *  Notify PNLite of an exception
 *
 *  @param exception the exception
 *  @param severity  the severity
 *  @param block     Configuration block for adding additional report
 * information
 */
- (void)notifyException:(NSException *_Nonnull)exception
             atSeverity:(PNLiteSeverity)severity
                  block:(PNLiteNotifyBlock _Nullable)block;

/**
 *  Notify PNLite of an exception. Only intended for React Native/Unity use.
 *
 *  @param exception the exception
 *  @param metaData  the metadata
 *  @param block     Configuration block for adding additional report
 * information
 */
- (void)internalClientNotify:(NSException *_Nonnull)exception
                    withData:(NSDictionary *_Nullable)metaData
                       block:(PNLiteNotifyBlock _Nullable)block;

/**
 *  Notify PNLite of an error
 *
 *  @param error the error
 *  @param block Configuration block for adding additional report information
 */
- (void)notifyError:(NSError *_Nonnull)error
              block:(PNLiteNotifyBlock _Nullable)block;

/**
 *  Add a breadcrumb
 *
 *  @param block configuration block
 */
- (void)addBreadcrumbWithBlock:
    (void (^_Nonnull)(PNLiteBreadcrumb *_Nonnull))block;

/**
 * Clear all stored breadcrumbs.
 */
- (void)clearBreadcrumbs;

/**
 *  Listen for notifications and attach breadcrumbs when received
 *
 *  @param notificationName name of the notification
 */
- (void)crumbleNotification:(NSString *_Nonnull)notificationName;

/**
 *  Enable or disable automatic breadcrumb collection based on configuration
 */
- (void)updateAutomaticBreadcrumbDetectionSettings;

@end
