//
//  FTXCallbackURL.m
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "Core/NSString+urlEncoding.h"
#import "FiftyThreeSdk/FTXCallbackURL.h"

@interface FTXCallbackURL ()
@property (nonatomic, readwrite) NSString *source;
@property (nonatomic, readwrite) NSURL *successUrl;
@property (nonatomic, readwrite) NSURL *errorUrl;
@property (nonatomic, readwrite) NSURL *cancelUrl;
@property (nonatomic, readwrite) NSString *action;
@end

NSString * const kFTXCallbackUrlSourceKey = @"x-source";
NSString * const kFTXCallbackUrlErrorKey = @"x-error";
NSString * const kFTXCallbackUrlCancelKey = @"x-cancel";
NSString * const kFTXCallbackUrlSuccessKey = @"x-error";

@implementation FTXCallbackURL
// Create a XCallbackUrl with named parameters. This sets up query parameters & url encodes the bits.
+ (FTXCallbackURL *)URLWithScheme:(NSString *)scheme
                             host:(NSString *)host
                           action:(NSString *)action
                           source:(NSString *)source
                       successUrl:(NSURL *)success
                         errorUrl:(NSURL *)error
                        cancelUrl:(NSURL *)cancel
{
    if (!scheme && !host && !action && !source)
    {
        return nil;
    }

    NSMutableString *baseUrl = [[NSString stringWithFormat:@"%@://%@/%@", scheme, host, action] mutableCopy];

    if (success || error || cancel  || source)
    {
        //OK we have some query parameters start adding them
        NSMutableArray *queryComponents = [@[] mutableCopy];

        if (source)
        {
            NSMutableString *component = [@"" mutableCopy];
            [component appendString:kFTXCallbackUrlSourceKey];
            [component appendString:@"="];
            [component appendString:[source urlEncodeUsingEncoding:NSUTF8StringEncoding]];
            [queryComponents addObject:component];
        }

        if (success)
        {
            NSMutableString *component = [@"" mutableCopy];
            [component appendString:kFTXCallbackUrlSuccessKey];
            [component appendString:@"="];
            [component appendString:[[success absoluteString] urlEncodeUsingEncoding:NSUTF8StringEncoding]];
            [queryComponents addObject:component];
        }

        if (error)
        {
            NSMutableString *component = [@"" mutableCopy];
            [component appendString:kFTXCallbackUrlErrorKey];
            [component appendString:@"="];
            [component appendString:[[error absoluteString] urlEncodeUsingEncoding:NSUTF8StringEncoding]];
            [queryComponents addObject:component];

        }

        if (cancel)
        {
            NSMutableString *component = [@"" mutableCopy];
            [component appendString:kFTXCallbackUrlCancelKey];
            [component appendString:@"="];
            [component appendString:[[cancel absoluteString] urlEncodeUsingEncoding:NSUTF8StringEncoding]];
            [queryComponents addObject:component];

        }
        [baseUrl appendString:@"?"];
        [baseUrl appendString:[@"&" join:queryComponents]];
    }

    FTXCallbackURL *url = [FTXCallbackURL URLWithString:baseUrl];

    url.source = source;
    url.action = action;
    url.successUrl = success;
    url.errorUrl = error;
    url.cancelUrl = cancel;

    return url;
}

+(NSDictionary*)parseQueryString:(NSString*)query
{
    if ([query length] == 0)
    {
        return nil;
    }

    NSMutableDictionary* parameters = [NSMutableDictionary dictionary];

    for (NSString* parameter in [query componentsSeparatedByString:@"&"])
    {
        NSRange range = [parameter rangeOfString:@"="];

        if (range.location != NSNotFound)
        {
            NSString * value = [parameter substringFromIndex:range.location+range.length];
            NSString * urlDecodedValue = [value urlDecodeUsingEncoding:NSUTF8StringEncoding];
            [parameters setValue:urlDecodedValue
                          forKey:[parameter substringToIndex:range.location]];
        }
        else
        {
            [parameters setValue:@"" forKey:[parameter urlDecodeUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    return parameters;
}

+ (FTXCallbackURL *)URLWithNSURL:(NSURL *)other
{
    FTXCallbackURL *url = [[FTXCallbackURL alloc] initWithString:[other absoluteString]];
    NSDictionary *queryParameters = [FTXCallbackURL parseQueryString:other.query];

    if ([queryParameters objectForKey:kFTXCallbackUrlSourceKey])
    {
        url.source = queryParameters[kFTXCallbackUrlSourceKey];
    }

    if ([queryParameters objectForKey:kFTXCallbackUrlSuccessKey])
    {
        url.successUrl = [NSURL URLWithString:queryParameters[kFTXCallbackUrlSuccessKey]];
    }

    if ([queryParameters objectForKey:kFTXCallbackUrlErrorKey])
    {
        url.errorUrl = [NSURL URLWithString:queryParameters[kFTXCallbackUrlErrorKey]];
    }

    if ([queryParameters objectForKey:kFTXCallbackUrlCancelKey])
    {
        url.cancelUrl = [NSURL URLWithString:queryParameters[kFTXCallbackUrlCancelKey]];
    }

    if (other.path)
    {
        url.action = ([url.path characterAtIndex:0] == '/')? [url.path substringFromIndex:1] : url.path;
    }
    return url;
}

@end