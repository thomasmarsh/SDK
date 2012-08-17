//
//  AppBladeOAuthView.h
//  AppBlade
//
//  Created by Michele Titolo on 8/13/12.
//  Copyright (c) 2012 Raizlabs Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol AppBladeOAuthViewDelegate <NSObject>

@required
- (void)finishedOAuthWithCode:(NSString*)code;

@end

@interface AppBladeOAuthView : UIView <UIWebViewDelegate>

@property (nonatomic, assign) id <AppBladeOAuthViewDelegate> delegate;

- (void)reset;
- (void)closeOAuthView;

@end