#import <Foundation/Foundation.h>
#import <_UIKitPrivate/UIDefines.h>

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

UIKIT_EXTERN
@interface UIImage : NSObject
+ (nullable UIImage *)systemImageNamed:(NSString *)name;
@end

NS_HEADER_AUDIT_END(nullability, sendability)
