#import <NanoTimeKit/NanoTimeKit.h>

NS_ASSUME_NONNULL_BEGIN

@class FaceEditingViewController;

@protocol FaceEditingViewControllerDelegate <NSObject>
@optional
- (void)faceEditingViewController:(FaceEditingViewController *)viewController didFinishEditingFace:(NTKFace *)face;
@end

@interface FaceEditingViewController : UIViewController
@property (nullable, nonatomic, assign) id<FaceEditingViewControllerDelegate> delegate;
- (instancetype)initWithFace:(NTKFace *)face;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
