#import <_UIKitPrivate/_UIKitPrivate.h>
#import <NanoTimeKit/NTKFace.h>

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

@interface NTKFaceViewController : UIViewController
- (instancetype)initWithFace:(NTKFace *)face configuration:(void (NS_NOESCAPE ^ _Nullable)(NTKFaceViewController *faceViewController))configuration;
- (BOOL)canStopEditing;
- (void)showEditingUIAnimated:(BOOL)animated fromZoomLevel:(NSUInteger)zoomLevel;
- (void)hideFaceEditingUIAnimated:(BOOL)animated destination:(NSUInteger)destination completion:(void (^ _Nullable)(void))completion;
@end

NS_HEADER_AUDIT_END(nullability, sendability)
