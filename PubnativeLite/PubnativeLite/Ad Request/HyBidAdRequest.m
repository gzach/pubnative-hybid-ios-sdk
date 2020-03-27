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

#import "HyBidAdRequest.h"
#import "PNLiteHttpRequest.h"
#import "PNLiteAdFactory.h"
#import "VrvAdFactory.h"
#import "PNLiteAdRequestModel.h"
#import "VrvAdRequestModel.h"
#import "PNLiteResponseModel.h"
#import "VrvResponseModel.h"
#import "HyBidAdModel.h"
#import "HyBidAdCache.h"
#import "PNLiteRequestInspector.h"
#import "HyBidLogger.h"
#import "HyBidSettings.h"
#import "XMLDictionary.h"

NSString *const PNLiteResponseOK = @"ok";
NSString *const PNLiteResponseError = @"error";
NSInteger const PNLiteResponseStatusOK = 200;
NSInteger const PNLiteResponseStatusVrvOK = 204;
NSInteger const PNLiteResponseStatusRequestMalformed = 422;

NSInteger const kRequestBothPending = 3000;
NSInteger const kRequestVerveResponded = 3001;
NSInteger const kRequestPubNativeResponded = 3002;
NSInteger const kRequestWinnerPicked = 3003;

NSInteger const kDefaultMRectZoneId = 5;
NSInteger const kDefaultBannerZoneId = 2;

@interface HyBidAdRequest () <PNLiteHttpRequestDelegate>

@property (nonatomic, weak) NSObject <HyBidAdRequestDelegate> *delegate;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong) NSString *zoneID;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSURL *requestURL;
@property (nonatomic, strong) NSURL *vrvRequestURL;
@property (nonatomic, assign) BOOL isSetIntegrationTypeCalled;
@property (nonatomic, strong) PNLiteAdFactory *adFactory;
@property (nonatomic, strong) VrvAdFactory *vrvAdFactory;
@property (nonatomic, assign) NSInteger requestStatus;

@end

@implementation HyBidAdRequest

- (void)dealloc {
    self.zoneID = nil;
    self.startTime = nil;
    self.requestURL = nil;
    self.vrvRequestURL = nil;
    self.delegate = nil;
    self.adFactory = nil;
    self.vrvAdFactory = nil;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.adFactory = [[PNLiteAdFactory alloc] init];
        self.vrvAdFactory = [[VrvAdFactory alloc] init];
        self.adSize = SIZE_320x50;
    }
    return self;
}

- (void)setIntegrationType:(IntegrationType)integrationType withZoneID:(NSString *)zoneID {
    self.zoneID = zoneID;
    self.requestURL = [self requestURLFromAdRequestModel:[self createAdRequestModelWithIntegrationType:integrationType]];
    self.vrvRequestURL = [self vrvRequestURLFromAdRequestModel:[self createVrvAdRequestModelWithIntegrationType:integrationType]];
    self.isSetIntegrationTypeCalled = YES;
}

- (void)setIntegrationType: (IntegrationType)integrationType {
    
    // This should be improved
    if ((self.adSize.width == 320 && self.adSize.height == 50) || (self.adSize.width == 320 && self.adSize.height == 100)) {
        self.zoneID = [@(kDefaultBannerZoneId) stringValue];
    } else if ((self.adSize.width == 300 && self.adSize.height == 250) || (self.adSize.width == 728 && self.adSize.height == 90)) {
        self.zoneID = [@(kDefaultMRectZoneId) stringValue];
    } else {
        self.zoneID = [@(kDefaultBannerZoneId) stringValue];
    }
    
    self.requestURL = [self requestURLFromAdRequestModel:[self createAdRequestModelWithIntegrationType:integrationType]];
    self.vrvRequestURL = [self vrvRequestURLFromAdRequestModel:[self createVrvAdRequestModelWithIntegrationType:integrationType]];
    self.isSetIntegrationTypeCalled = YES;
}

- (void)requestAdWithDelegate:(NSObject<HyBidAdRequestDelegate> *)delegate withZoneID:(NSString *)zoneID {
    if (self.isRunning) {
        NSError *runningError = [NSError errorWithDomain:@"Request is currently running, droping this call." code:0 userInfo:nil];
        [self invokeDidFail:runningError];
    } else if(!delegate) {
        [HyBidLogger warningLogFromClass:NSStringFromClass([self class]) fromMethod:NSStringFromSelector(_cmd) withMessage:@"Given delegate is nil and required, droping this call."];
    } else if(!zoneID || zoneID.length == 0) {
        [HyBidLogger warningLogFromClass:NSStringFromClass([self class]) fromMethod:NSStringFromSelector(_cmd) withMessage:@"Zone ID nil or empty, droping this call."];
    }
    else {
        self.startTime = [NSDate date];
        self.delegate = delegate;
        self.zoneID = zoneID;
        self.isRunning = YES;
        [self invokeDidStart];
        
        if (!self.isSetIntegrationTypeCalled) {
            [self setIntegrationType:HEADER_BIDDING withZoneID:zoneID];
        }

        self.requestStatus = kRequestBothPending;
        [[PNLiteHttpRequest alloc] startWithUrlString:self.requestURL.absoluteString withMethod:@"GET" delegate:self];
        
        [[PNLiteHttpRequest alloc] startWithUrlString:self.vrvRequestURL.absoluteString withMethod:@"GET" delegate:self];
    }
}

- (void)requestAdWithDelegate:(NSObject<HyBidAdRequestDelegate> *)delegate {
    if (self.isRunning) {
        NSError *runningError = [NSError errorWithDomain:@"Request is currently running, droping this call." code:0 userInfo:nil];
        [self invokeDidFail:runningError];
    } else if(!delegate) {
        [HyBidLogger warningLogFromClass:NSStringFromClass([self class]) fromMethod:NSStringFromSelector(_cmd) withMessage:@"Given delegate is nil and required, droping this call."];
    }
    
    else {
        self.startTime = [NSDate date];
        self.delegate = delegate;
        // This should be improved
        if ((self.adSize.width == 320 && self.adSize.height == 50) || (self.adSize.width == 320 && self.adSize.height == 100)) {
            self.zoneID = [@(kDefaultBannerZoneId) stringValue];
        } else if ((self.adSize.width == 300 && self.adSize.height == 250) || (self.adSize.width == 728 && self.adSize.height == 90)) {
            self.zoneID = [@(kDefaultMRectZoneId) stringValue];
        } else {
            self.zoneID = [@(kDefaultBannerZoneId) stringValue];
        }
        
        self.isRunning = YES;
        [self invokeDidStart];
        
        if (!self.isSetIntegrationTypeCalled) {
            [self setIntegrationType:HEADER_BIDDING withZoneID:self.zoneID];
        }

        self.requestStatus = kRequestBothPending;
        [[PNLiteHttpRequest alloc] startWithUrlString:self.requestURL.absoluteString withMethod:@"GET" delegate:self];
        
        [[PNLiteHttpRequest alloc] startWithUrlString:self.vrvRequestURL.absoluteString withMethod:@"GET" delegate:self];
    }
}

- (PNLiteAdRequestModel *)createAdRequestModelWithIntegrationType:(IntegrationType)integrationType {
    [HyBidLogger debugLogFromClass:NSStringFromClass([self class]) fromMethod:NSStringFromSelector(_cmd) withMessage:[NSString stringWithFormat:@"%@",[self requestURLFromAdRequestModel: [self.adFactory createAdRequestWithZoneID:self.zoneID
                                                                                                                                                                                                                      andWithAdSize:[self adSize]
                                                                                                                                                                                                             andWithIntegrationType:integrationType]].absoluteString]];
    return [self.adFactory createAdRequestWithZoneID:self.zoneID
                                       andWithAdSize:[self adSize]
                              andWithIntegrationType:integrationType];
}

- (VrvAdRequestModel *)createVrvAdRequestModelWithIntegrationType:(IntegrationType)integrationType {
    VrvAdRequestModel *vrvRequestModel = [self.vrvAdFactory createVrvAdRequestWithZoneID:self.zoneID
    withAdSize:[self adSize]];
    [HyBidLogger debugLogFromClass:NSStringFromClass([self class]) fromMethod:NSStringFromSelector(_cmd) withMessage:[NSString stringWithFormat:@"%@",[self vrvRequestURLFromAdRequestModel: vrvRequestModel].absoluteString]];
    return vrvRequestModel;
}

- (NSURL*)requestURLFromAdRequestModel:(PNLiteAdRequestModel *)adRequestModel {
    NSURLComponents *components = [NSURLComponents componentsWithString:[HyBidSettings sharedInstance].apiURL];
    components.path = @"/api/v3/native";
    if (adRequestModel.requestParameters) {
        NSMutableArray *query = [NSMutableArray array];
        NSDictionary *parametersDictionary = adRequestModel.requestParameters;
        for (id key in parametersDictionary) {
            [query addObject:[NSURLQueryItem queryItemWithName:key value:parametersDictionary[key]]];
        }
        components.queryItems = query;
    }
    return components.URL;
}

- (NSURL*)vrvRequestURLFromAdRequestModel:(VrvAdRequestModel *)adRequestModel {
    NSURLComponents *components = [NSURLComponents componentsWithString:@"https://adcel.vrvm.com"];
    components.path = @"/banner";
    if (adRequestModel.requestParameters) {
        NSMutableArray *query = [NSMutableArray array];
        NSDictionary *parametersDictionary = adRequestModel.requestParameters;
        for (id key in parametersDictionary) {
            [query addObject:[NSURLQueryItem queryItemWithName:key value:parametersDictionary[key]]];
        }
        components.queryItems = query;
    }
    return components.URL;
}

- (void)invokeDidStart {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(requestDidStart:)]) {
            [self.delegate requestDidStart:self];
        }
    });
}

- (void)invokeDidLoad:(HyBidAd *)ad {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isRunning = NO;
        if (self.delegate && [self.delegate respondsToSelector:@selector(request:didLoadWithAd:)]) {
            [self.delegate request:self didLoadWithAd:ad];
        }
        self.delegate = nil;
    });
}

- (void)invokeDidFail:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isRunning = NO;
        [HyBidLogger errorLogFromClass:NSStringFromClass([self class]) fromMethod:NSStringFromSelector(_cmd) withMessage:error.localizedDescription];
        if(self.delegate && [self.delegate respondsToSelector:@selector(request:didFailWithError:)]) {
            [self.delegate request:self didFailWithError:error];
        }
        self.delegate = nil;
    });
}

- (NSDictionary *)createDictionaryFromData:(NSData *)data {
    NSError *parseError;
    NSData *objectData = [@"{\"status\": \"ok\",\"ads\": []}" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDictonary = [NSJSONSerialization JSONObjectWithData:objectData
                                                                  options:NSJSONReadingMutableContainers
                                                                    error:&parseError];

    if (parseError) {
        [self invokeDidFail:parseError];
        return nil;
    } else {
        return jsonDictonary;
    }
}

- (NSDictionary *)createXmlFromData:(NSData *)data {
    NSString *stringData = @"<ad>\n\t<media>\n\t\t<image_url />\n\t\t<image_alt />\n\t</media>\n\t<tracking>\n\t\t<tracking_image_url />\n\t</tracking>\n\t<copy>\n\t\t<leadin />\n\t</copy>\n\t<clickthrough>\n\t\t<url />\n\t</clickthrough>\n\t<rawResponse>\n\t\t<useRawResponse>true</useRawResponse>\n\t\t<response>\n\t\t\t<![CDATA[<html><head><meta name=\"HandheldFriendly\" content=\"true\" /> <meta name=\"MobileOptimized\" content=\"width\" /> <meta name=\"viewport\" content=\"width=device-width, minimum-scale=1, maximum-scale=1, user-scalable=no\" /></head> <body style=\"margin: 0; padding: 0\"><div class=\"vrvWrap\" style=\"width: 100%; height: 100%;\"><img style=\"display: none;\" onerror=\"(function(w, d, i) { var tagElement = i.parentNode;\n\t\t\tvar c = {\n\t\t\t'creativeParams': {\n\t\t\t'variant': '',\n\t\t\t'segmentId': ''\n\t\t\t},\n\t\t\t'redirectUrl': '',\n\t\t\t'trackImp': '',\n\t\t\t'trackClick': '', /* Leave blank if this is the exact same URL as redirectUrl */\n\t\t\t'type': 'banner',\n\t\t\t'width': '320',\n\t\t\t'height': '50',\n\t\t\t'bannerUrl': 'https://ad.vrvm.com/creative/custom/dell/nat8153-world/NAT-8155/banner/banner.html'\n\t\t\t};\n\t\t\t'function'!=typeof Object.assign&amp;&amp;!function(){Object.assign=function(n){'use strict';if(void 0===n||null===n)throw new TypeError('Cannot convert undefined or null to object');for(var t=Object(n),r=1;r<arguments.length;r++){var e=arguments[r];if(void 0!==e&amp;&amp;null!==e)for(var o in e)e.hasOwnProperty(o)&amp;&amp;(t[o]=e[o])}return t}}();\n\t\t\tvar d = {\n\t\t\t'trackBase': 'http://rtb-east.vervemobile.com/ev?adnet=56&amp;b=vrvexch&amp;c=407299&amp;f=358882&amp;mpz=H4sIAAAAAAAE_4xUTY_kJhD9L3W2R4DttuG2o7nlmOMqQmWge9jBwAL2TifKf4-w3dl8rEbrk3n16pvHH2A1CCD1YxMZzKjmq-FM4dwjpSNDTblh0EDJIOgwDazrJj6OdGrgNXwDQcml_uUCAmJrMJd2tlqb1DJ6eYcGkrnZ4EHAmndzDw1sIGCYCdfkKhlhhHSUt5TTnrG_z_KL8W_W5zYUzG2KSzuv1ul2wVxMatHrtphc2o5CA2aT5R4NCFDOqjdoAFcl7U_2Vrmz1VLFBQR54sPYwNU6J_Wi5T6goR-6Cf6B5qRAgMfiHqjCIlXQJoP4DBZn1sNvpwPq7SNzSI8sZGTdI97VlSN3N0zTVFewl4Qnt-ecXviDrFLZDnZPRsa_48GXhKocrXVnPQumm_W11UsDt4BO2iVmGU2S2aiKU0LYwHvaQMJv8ocUQgfOL4R3DVi_ybxG6XGpK9jSZt7VK3w3lGM3_zacIMZ4Mv87QcrqBGvwfQeos34z77hEZyR6jFKF5Smus8diN_P0Sf_68suTNkuAI3Nc5_97nrnm1WtnDvMHYaJTMtvfa1cdI-8DgWbHUK_eHvsGAcuC0IDelFz3SqeBPRPKXtoLe7m0PX1-bife9-30iVDWDXx85gM8HDIIeLifI1nCbF2tdM1J3sMMgnJOm_14M16bVJNCA5vLUoXVl3Tf796ushqsGhZTUjjhgdCDfajxRMF_OYPEkAu6B0xGwneZuixjMsrmXcGUkCNIqDXbkE9nFbyXORqjQcCcAuoZvT6Nq7yiqo_HZ3Bfl7rQGvXris6WO4iBNBBikaokaeojQo8zulsAAclsMr9iMnKrMq_Mep_frL_JXekZREmraQC1N4dghksD5VaX88Oy_vwrAAD__xEaaCn0BAAA&amp;p=&amp;pc=0.9570000171661377&amp;r=000002805e7cbfe92cab4a1172ad19e2&amp;rd=http%3A%2F%2Fgo.vrvm.com%2Ft%3F&amp;rpz=H4sIAAAAAAAE_4ySS27cPBCE79JrcUBST2rngXf_8j8A0SI5Nm3xAT4UG0HuHkijSRYOgmj5VXV1UejvYDXMQPePT7Q3o1puRnCFS4eMjRw1E4ZDA68hF5ghEoO5kMVqbRLhbPiABpJ5scHDDDUTg7l00MAGM_QLFZreJKec0pYJwgTrOJecckpbJuSb8e_WZxIKZpKiI0u1qyYOczGJoNekmFxIy6ABrEpa_W9lsSq5WC1VdDDTi-jHBm52XWVIWh4v7unIWzjpbS132vbTNO2vPcx4ejsh2CAeZpXKdnd3dOTiNw--JFTlvrQ9ox2mF-v3EkMDLwFXaV3MMpoks1E7Z5TyXnSsgYTf5B8tlPVCDFS0DVi_yVyj9OgMzLClzXyoV2h-CeUzfhVOiDGezuMfoM763Xygi6uR6DFKFdwl1sVjsZu5POn_n_-7aOMC3BfHunydPBOX6vVq7vJfYuKqJOrqbZEq6L2pcwgN6E3JerSaen6ljD-TgT8PpGPXK5lE15HpiTLe9mK8ih4eAxlm2Me3NUsVqi_p85Fb80NwpqRw4p6y5nCn42ZPCv4N7jiGXHB9YDpScRzzmmXYd9mQoQHU3hRpNcz98ONnAAAA__-puAo9QwMAAA%3D%3D&amp;ui=852B012D-62D6-41BB-8944-8A0123597B95&amp;uis=a',\n\t\t\t'appmw': 'app',\n\t\t\t'latitude': '40.7895',\n\t\t\t'longitude': '-74.0628',\n\t\t\t'flightId': '358882',\n\t\t\t'creativeId': '407299',\n\t\t\t'requestId': '000002805e7cbfe92cab4a1172ad19e2',\n\t\t\t'adnetId': '56',\n\t\t\t'redirectMacroUrl': '%%V3RD_PARTY_CLICK_URL_UNESC%%'\n\t\t\t};\n\t\t\tObject.assign(c, d);\n\t\t\tvar script = document.createElement('script'); script.src = 'https://creative-platform.vrvm.com/tagjs/tag.1.6.0.js'; script.onload = function() { Verve.controllers.factories.AdFactory.makeAd(tagElement, c); }; tagElement.appendChild(script); })(window, document, this);\" src=\"data:image/png,vrvm\" /></div>\n\t\t\t<div style=\"position:absolute; z-index:-9999; display:none;\">\n\t\t\t<!-- DELETE THIS LINE AND ADD ALL THIRD PARTY TRACKERS HERE -->\n\t\t\t<img src=“https://beacon.krxd.net/ad_impression.gif?confid=uh9ux9gjh&amp;campaignid=23707717&amp;advertiserid=9643275&amp;placementid=266456533&amp;adid=461285877&amp;creativeid=127934744&amp;siteid=5855354“>\n\t\t\t<img src=“https://t.myvisualiq.net/impression_pixel?r=000002805e7cbfe92cab4a1172ad19e2&amp;et=i&amp;ago=212&amp;ao=871&amp;aca=23707717&amp;si=5855354&amp;ci=127934744&amp;pi=266456533&amp;ad=461285877&amp;advt=9643275&amp;chnl=-7&amp;vndr=115&amp;sz=7571&amp;u=%pu=!;&amp;viq_did=852B012D-62D6-41BB-8944-8A0123597B95=!;&amp;pt=I“>\n\t\t\t<script src=\"https://cdn.doubleverify.com/dvtp_src.js?ctx=569086&amp;cmp=23707717&amp;sid=5855354&amp;plc=266456533&amp;adsrv=1&amp;btreg=&amp;btadsrv=&amp;crt=&amp;tagtype=&amp;dvtagver=6.1.src\" type=\"text/javascript\"></script>\n\t\t\t<script src=\"mraid.js\">\n\t\t\t</script><script src=\"https://cdn.doubleverify.com/dvtp_src.js?ctx=3891363&amp;cmp=DV036028&amp;sid=verve&amp;plc=DV-Verve-20170601001&amp;num=&amp;adid=&amp;advid=3819603&amp;adsrv=0&amp;region=30&amp;app=com.pubnative.AdSDK.demo&amp;dvtagver=6.1.src&amp;DVP_CDID=852B012D-62D6-41BB-8944-8A0123597B95&amp;DVP_ADV=54538&amp;DVP_CMP=50723&amp;DVP_LINE=358882&amp;DVP_CRT=407299&amp;DVP_PUB=vrvexch&amp;DVP_SUP=adsdkexample_anap_com.pubnative.AdSDK.demo\" type=\"text/javascript\"></script>\n\t\t\t<noscript class=\"MOAT-verveinappvrv481346465113?moatClientLevel1=54538&amp;moatClientLevel2=50723&amp;moatClientLevel3=358882&amp;moatClientLevel4=407299&amp;moatClientSlicer1=vrvexch&amp;moatClientSlicer2=&amp;zMoatSUPPLY=adsdkexample_anap_com.pubnative.AdSDK.demo\"></noscript><script src=\"https://z.moatads.com/verveinappvrv481346465113/moatad.js#moatClientLevel1=54538&amp;moatClientLevel2=50723&amp;moatClientLevel3=358882&amp;moatClientLevel4=407299&amp;moatClientSlicer1=vrvexch&amp;moatClientSlicer2=&amp;zMoatSUPPLY=adsdkexample_anap_com.pubnative.AdSDK.demo\" type=\"text/javascript\"></script>\n\t\t\t</div>\n\t\t\t</body></html><div style=\"top:0;right:0;width:1px;height:1px;position:absolute;border:none;visibility:hidden;\"><img src=\"http://rtb-east.vervemobile.com/imp/vrvexch?i=000002805e7cbfe92cab4a1172ad19e2&amp;mpz=H4sIAAAAAAAE_4xUTY_kJhD9L3W2R4DttuG2o7nlmOMqQmWge9jBwAL2TifKf4-w3dl8rEbbp-a9qldVPBd_gNUggNQfm8hgRjVfDWcK5x4pHRlqyg2DBkoGQYdpYF038XGkUwOv4RsISi71Xy4gILYGc2lnq7VJLaOXd2ggmZsNHgSsead7aGADAcNMuCZXyQgjpKO8pZz2jP19ll-Mf7M-t6FgblNc2nm1TrcL5mJSi163xeTSdhQaMJss92hAgF0iNICrkj87WY2drZYqLiDIEx_GBq7WOakXLXeRoR-6Cf6B5qRAgMfiHqjCIlXQJoP4DBZn1sNvZwLq7SM6pEcVMrLuoXd15ajdDdM0VQP2lvCM7TmnF_4IVqlsR3RPRsa_48GXhKoco3VnPwumm_V11EsDt4BO2iVmGU2S2aiKU0LYwHvaQMJv8ochhA6cXwjvGrB-k3mN0uNSDdjSZt7VK3wnyuHMv4kTxFjtqhL_vUHK6g1WZvcAddZv5h2X6IxEj1GqsDzFdfZY7GaePulfX3550mYJcFSO6_z_zLOrefXamYP-QCY6JbP9vU7VMfI-EGh2DPXq7eE3CFgWhAb0puS6dzoN7JlQ9tJe2Mul7enzczvxvm-nT4SybuDjMx_gkZBBwCP9vJIlzNbVTtec5D3MICjntNmPN-O1SbUoNLC5LFVYfUn3_dvbd6yKVWIxJYUTHgg9oo9dPFHwX06RGHJB94DJSPi-pC7LmIyyed9fSsghEmrPNuQzWQXvZY7GaBAwp4B6Rq9PcpVXVPXp-Azu61INrapfV3S23EEMpIEQi1QlSVOfEHqc0d0CCEhmk_kVk5FbXfIaWb_nN-tvUjmr3jKIklbTAGpvjoUZLg2UWzXnh239-VcAAAD__w-eJf_yBAAA&amp;pc=0.9570000171661377\" height=\"1\" width=\"1\" alt=\"\" /></div><div style=\"top:0;right:0;width:1px;height:1px;position:absolute;border:none;visibility:hidden;\"><img src=\"http://go.vrvm.com/t?adnet=56&amp;b=vrvexch&amp;c=407299&amp;e=AdImpInternal&amp;f=358882&amp;p=&amp;pc=0.9570000171661377&amp;r=000002805e7cbfe92cab4a1172ad19e2&amp;rpz=H4sIAAAAAAAE_4ySS27cPBCE79JrcUBST2rngXf_8j8A0SI5Nm3xAT4UG0HuHkijSRYOgmj5VXV1UejvYDXMQPePT7Q3o1puRnCFS4eMjRw1E4ZDA68hF5ghEoO5kMVqbRLhbPiABpJ5scHDDDUTg7l00MAGM_QLFZreJKec0pYJwgTrOJecckpbJuSb8e_WZxIKZpKiI0u1qyYOczGJoNekmFxIy6ABrEpa_W9lsSq5WC1VdDDTi-jHBm52XWVIWh4v7unIWzjpbS132vbTNO2vPcx4ejsh2CAeZpXKdnd3dOTiNw--JFTlvrQ9ox2mF-v3EkMDLwFXaV3MMpoks1E7Z5TyXnSsgYTf5B8tlPVCDFS0DVi_yVyj9OgMzLClzXyoV2h-CeUzfhVOiDGezuMfoM763Xygi6uR6DFKFdwl1sVjsZu5POn_n_-7aOMC3BfHunydPBOX6vVq7vJfYuKqJOrqbZEq6L2pcwgN6E3JerSaen6ljD-TgT8PpGPXK5lE15HpiTLe9mK8ih4eAxlm2Me3NUsVqi_p85Fb80NwpqRw4p6y5nCn42ZPCv4N7jiGXHB9YDpScRzzmmXYd9mQoQHU3hRpNcz98ONnAAAA__-puAo9QwMAAA%3D%3D&amp;ui=852B012D-62D6-41BB-8944-8A0123597B95&amp;uis=a\" height=\"1\" width=\"1\" alt=\"\" /></div>]]>\n\t\t</response>\n\t</rawResponse>\n</ad>";
    NSData *objectData = [stringData dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDictonary = [NSDictionary dictionaryWithXMLData:objectData];
    return jsonDictonary;
}

- (void)processResponseWithData:(NSData *)data {
    NSDictionary *jsonDictonary = [self createDictionaryFromData:data];
    if (jsonDictonary) {
        PNLiteResponseModel *response = [[PNLiteResponseModel alloc] initWithDictionary:jsonDictonary];
        if(!response) {
            NSError *error = [NSError errorWithDomain:@"Can't parse JSON from server"
                                                 code:0
                                             userInfo:nil];
            if (self.requestStatus == kRequestWinnerPicked) {
                NSLog(@"PApi has failure but VAPI was faster.");
                return;
            }

            if (self.requestStatus == kRequestBothPending) {
                self.requestStatus = kRequestPubNativeResponded;
            } else {
                [self invokeDidFail:error];
            }
        } else if ([PNLiteResponseOK isEqualToString:response.status]) {
            NSMutableArray *responseAdArray = [[NSArray array] mutableCopy];
            for (HyBidAdModel *adModel in response.ads) {
                HyBidAd *ad = [[HyBidAd alloc] initWithData:adModel];
                [[HyBidAdCache sharedInstance] putAdToCache:ad withZoneID:self.zoneID];
                [responseAdArray addObject:ad];
            }
            if (responseAdArray.count > 0) {
                if (self.requestStatus == kRequestWinnerPicked) {
                    NSLog(@"PAPI responded but VAPI was faster.");
                    return;
                }
                
                self.requestStatus = kRequestWinnerPicked;
                
                [self invokeDidLoad:responseAdArray.firstObject];
            } else {
                NSError *error = [NSError errorWithDomain:@"No fill"
                                                     code:0
                                                 userInfo:nil];
                if (self.requestStatus == kRequestWinnerPicked) {
                    NSLog(@"PApi did not fill but VAPI was faster.");
                    return;
                }

                if (self.requestStatus == kRequestBothPending) {
                    self.requestStatus = kRequestPubNativeResponded;
                } else {
                    [self invokeDidFail:error];
                }
            }
        } else {
            NSString *errorMessage = [NSString stringWithFormat:@"HyBidAdRequest - %@", response.errorMessage];
            NSError *responseError = [NSError errorWithDomain:errorMessage
                                                         code:0
                                                     userInfo:nil];
            if (self.requestStatus == kRequestWinnerPicked) {
                NSLog(@"PApi has failure but VAPI was faster.");
                return;
            }

            if (self.requestStatus == kRequestBothPending) {
                self.requestStatus = kRequestPubNativeResponded;
            } else {
                [self invokeDidFail:responseError];
            }
        }
    }
}

- (void)processXmlResponseWithData:(NSData *)data {
    NSDictionary *xmlDictonary = [self createXmlFromData:data];
    if (xmlDictonary) {
        VrvResponseModel *response = [[VrvResponseModel alloc] initWithXml:xmlDictonary];
        if(!response) {
            NSError *error = [NSError errorWithDomain:@"Can't parse XML from server"
                                                 code:0
                                             userInfo:nil];
            if (self.requestStatus == kRequestWinnerPicked) {
                NSLog(@"VAPI has failure but PAPI was faster.");
                return;
            }

            if (self.requestStatus == kRequestBothPending) {
                self.requestStatus = kRequestVerveResponded;
            } else {
                [self invokeDidFail:error];
            }
        } else if ([PNLiteResponseOK isEqualToString:response.status]) {
            NSMutableArray *responseAdArray = [[NSArray array] mutableCopy];
            
            HyBidAd *ad = [[HyBidAd alloc] initWithVrvXml:xmlDictonary];
            [[HyBidAdCache sharedInstance] putAdToCache:ad withZoneID:self.zoneID];
            [responseAdArray addObject:ad];
            
            if (responseAdArray.count > 0) {
                if (self.requestStatus == kRequestWinnerPicked) {
                    NSLog(@"VAPI has response but PAPI was faster.");
                    return;
                }
                
                self.requestStatus = kRequestWinnerPicked;
                
                [self invokeDidLoad:responseAdArray.firstObject];
            } else {
                NSError *error = [NSError errorWithDomain:@"No fill"
                                                     code:0
                                                 userInfo:nil];
                if (self.requestStatus == kRequestWinnerPicked) {
                    NSLog(@"VAPI did not fill but PAPI was faster.");
                    return;
                }

                if (self.requestStatus == kRequestBothPending) {
                    self.requestStatus = kRequestVerveResponded;
                } else {
                    [self invokeDidFail:error];
                }
            }
        } else {
            NSString *errorMessage = @"HyBidAdRequest - An error has ocurred fetching the ad";
            NSError *responseError = [NSError errorWithDomain:errorMessage
                                                         code:0
                                                     userInfo:nil];
            if (self.requestStatus == kRequestWinnerPicked) {
                NSLog(@"VAPI has failure but PAPI was faster.");
                return;
            }

            if (self.requestStatus == kRequestBothPending) {
                self.requestStatus = kRequestVerveResponded;
            } else {
                [self invokeDidFail:responseError];
            }
        }
    }
}

#pragma mark PNLiteHttpRequestDelegate

- (void)request:(PNLiteHttpRequest *)request didFinishWithData:(NSData *)data statusCode:(NSInteger)statusCode {
    if (request.urlString == self.requestURL.absoluteString) {
        if(PNLiteResponseStatusOK == statusCode || PNLiteResponseStatusRequestMalformed == statusCode) {
            NSString *responseString;
            if ([self createDictionaryFromData:data]) {
                responseString = [NSString stringWithFormat:@"%@",[self createDictionaryFromData:data]];
            } else {
                responseString = [NSString stringWithFormat:@"Error while creating a JSON Object with the response. Here is the raw data: \r\r%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
            }
        
            [[PNLiteRequestInspector sharedInstance] setLastRequestInspectorWithURL:self.requestURL.absoluteString
                                                                   withResponse:responseString
                                                                    withLatency:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceDate:self.startTime] * 1000.0]];
            [self processResponseWithData:data];
        } else {
            NSError *statusError = [NSError errorWithDomain:@"PNLiteHttpRequestDelegate - Server error: status code" code:statusCode userInfo:nil];
            if (self.requestStatus == kRequestWinnerPicked) {
                NSLog(@"PApi has failure but VAPI was faster.");
                return;
            }

            if (self.requestStatus == kRequestBothPending) {
                self.requestStatus = kRequestPubNativeResponded;
            } else {
                [self invokeDidFail:statusError];
            }
        }
    } else if (request.urlString == self.vrvRequestURL.absoluteString) {
        // Repeat this condition because Adcel API has different response codes
        if(PNLiteResponseStatusOK == statusCode || PNLiteResponseStatusVrvOK == statusCode || PNLiteResponseStatusRequestMalformed == statusCode) {
            NSString *responseString;
            if ([self createXmlFromData:data]) {
                responseString = [NSString stringWithFormat:@"%@",[self createXmlFromData:data]];
            } else {
                responseString = [NSString stringWithFormat:@"Error while creating a XML Object with the response. Here is the raw data: \r\r%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
            }
            
            [self processXmlResponseWithData:data];
        } else {
            NSError *statusError = [NSError errorWithDomain:@"PNLiteHttpRequestDelegate - Server error: status code" code:statusCode userInfo:nil];
            if (self.requestStatus == kRequestWinnerPicked) {
                NSLog(@"VAPI has failure but PAPI was faster.");
                return;
            }

            if (self.requestStatus == kRequestBothPending) {
                self.requestStatus = kRequestVerveResponded;
            } else {
                [self invokeDidFail:statusError];
            }
        }
    }
}

- (void)request:(PNLiteHttpRequest *)request didFailWithError:(NSError *)error {
    if (request.urlString == self.requestURL.absoluteString) {
        [[PNLiteRequestInspector sharedInstance] setLastRequestInspectorWithURL:self.requestURL.absoluteString
                                                               withResponse:error.localizedDescription
                                                                withLatency:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceDate:self.startTime] * 1000.0]];
        if (self.requestStatus == kRequestWinnerPicked) {
            NSLog(@"PApi has failure but VAPI was faster.");
            return;
        }

        if (self.requestStatus == kRequestBothPending) {
            self.requestStatus = kRequestPubNativeResponded;
        } else {
            [self invokeDidFail:error];
        }
    } else if (request.urlString == self.vrvRequestURL.absoluteString) {
        if (self.requestStatus == kRequestWinnerPicked) {
            NSLog(@"VAPI has failure but PAPI was faster.");
            return;
        }

        if (self.requestStatus == kRequestBothPending) {
            self.requestStatus = kRequestVerveResponded;
        } else {
            [self invokeDidFail:error];
        }
    }
}

@end
