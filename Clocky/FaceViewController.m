#import "FaceViewController.h"
#import "FaceBundleListViewController.h"
#import "FaceEditingViewController.h"
#import "Defines.h"
#import <NanoTimeKit/NanoTimeKit.h>
#import <CoreMotion/CoreMotion.h>

@interface FaceViewController () <FaceBundleListViewControllerDelegate, FaceEditingViewControllerDelegate>
@property (nullable, nonatomic, retain, direct) NTKFaceViewController *faceViewController;
@property (nullable, nonatomic, retain, direct) NTKFace *selectedFace;
@end

@implementation FaceViewController

- (void)dealloc {
    [_faceViewController release];
    [_selectedFace release];
    [super dealloc];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self requestMotionPermission];
    [self showInitialFace];
    [self configureLongPressGesture];
}

- (void)requestMotionPermission __attribute__((objc_direct)) {
    if ([CMPedometer isStepCountingAvailable] && [CMPedometer authorizationStatus] == CMAuthorizationStatusNotDetermined) {
        CMPedometer *pedometer = [[CMPedometer alloc] init];
        NSDate *now = [NSDate date];
        [pedometer queryPedometerDataFromDate:[now dateByAddingTimeInterval:-60.0] toDate:now withHandler:^(CMPedometerData * _Nullable data, NSError * _Nullable error) {
            if (error != nil) {
                NSLog(@"Motion permission request failed: %@", error);
            }
        }];
        [pedometer release];
    }
}

- (void)showInitialFace __attribute__((objc_direct)) {
    NTKFace * _Nullable savedFace = [self loadSelectedFace];
    if (savedFace != nil) {
        [self showFace:savedFace];
        return;
    }
    __block __kindof NTKFaceBundle * _Nullable firstBundle = nil;
    [NTKFaceBundleManager.sharedManager enumerateFaceBundlesOnDevice:CLKDevice.currentDevice includingLegacy:YES withBlock:^(__kindof NTKFaceBundle *faceBundle) {
        if (firstBundle == nil) {
            firstBundle = [faceBundle retain];
        }
    }];
    if (firstBundle != nil) {
        NTKFace * _Nullable face = [firstBundle defaultFaceForDevice:CLKDevice.currentDevice];
        if (face != nil) {
            [self showFace:face];
            if ([NSUserDefaults.standardUserDefaults dataForKey:selectedFaceArchiveKey()] == nil) {
                [self saveSelectedFace:face];
            }
        }
    }
    [firstBundle release];
}

- (nullable NTKFace *)loadSelectedFace __attribute__((objc_direct)) {
    NSData * _Nullable data = [NSUserDefaults.standardUserDefaults dataForKey:selectedFaceArchiveKey()];
    if (data == nil) return nil;
    NSError * _Nullable error = nil;
    @try {
        NTKFace * _Nullable face = [NSKeyedUnarchiver unarchivedObjectOfClass:[NTKFace class] fromData:data error:&error];
        if (face == nil) NSLog(@"Failed to restore selected face: %@", error);
        return face;
    } @catch (NSException *exception) {
        NSLog(@"Failed to restore selected face: %@", exception);
        return nil;
    }
}

- (void)saveSelectedFace:(NTKFace *)face __attribute__((objc_direct)) {
    NSError * _Nullable error = nil;
    @try {
        NSData * _Nullable data = [NSKeyedArchiver archivedDataWithRootObject:face requiringSecureCoding:YES error:&error];
        if (data != nil) {
            [NSUserDefaults.standardUserDefaults setObject:data forKey:selectedFaceArchiveKey()];
        } else {
            NSLog(@"Failed to archive selected face: %@", error);
        }
    } @catch (NSException *exception) {
        NSLog(@"Failed to archive selected face: %@", exception);
    }
}

- (void)configureLongPressGesture __attribute__((objc_direct)) {
    UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didTriggerLongPressGestureRecognizer:)];
    [self.view addGestureRecognizer:longPressGestureRecognizer];
    [longPressGestureRecognizer release];
}

- (void)showFace:(NTKFace *)face __attribute__((objc_direct)) {
    if (self.faceViewController != nil) {
        [self.faceViewController willMoveToParentViewController:nil];
        [self.faceViewController.view removeFromSuperview];
        [self.faceViewController removeFromParentViewController];
        self.faceViewController = nil;
    }
    
    NTKFaceViewController *faceViewController = [[NTKFaceViewController alloc] initWithFace:face configuration:nil];
    [self addChildViewController:faceViewController];
    faceViewController.view.frame = self.view.bounds;
    faceViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:faceViewController.view];
    [faceViewController didMoveToParentViewController:self];
    
    self.faceViewController = faceViewController;
    self.selectedFace = face;
    [faceViewController release];
}

- (void)didTriggerLongPressGestureRecognizer:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    
    FaceBundleListViewController *listViewController = [[FaceBundleListViewController alloc] init];
    listViewController.delegate = self;
    PUICNavigationController *navigationController = [[PUICNavigationController alloc] initWithRootViewController:listViewController];
    [self presentViewController:navigationController animated:YES completion:nil];
    [navigationController release];
    [listViewController release];
}

#pragma mark - FaceBundleListViewControllerDelegate

- (void)faceBundleListViewController:(FaceBundleListViewController *)viewController didSelectFaceBundle:(__kindof NTKFaceBundle *)faceBundle {
    NTKFace * _Nullable face = [faceBundle defaultFaceForDevice:CLKDevice.currentDevice];
    if (face == nil) {
        NSLog(@"No default face for bundle: %@", faceBundle);
        return;
    }
    [self showFace:face];
    [self saveSelectedFace:face];
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)faceBundleListViewControllerDidRequestEditing:(FaceBundleListViewController *)viewController {
    if (self.selectedFace == nil) return;
    [viewController dismissViewControllerAnimated:YES completion:^{
        [self presentFaceEditor];
    }];
}

- (void)presentFaceEditor __attribute__((objc_direct)) {
    NTKFace * _Nullable face = self.selectedFace;
    if (face == nil) return;
    FaceEditingViewController *editor = [[FaceEditingViewController alloc] initWithFace:face];
    editor.delegate = self;
    PUICNavigationController *navigationController = [[PUICNavigationController alloc] initWithRootViewController:editor];
    [self presentViewController:navigationController animated:YES completion:nil];
    [navigationController release];
    [editor release];
}

- (void)faceEditingViewController:(FaceEditingViewController *)viewController didFinishEditingFace:(NTKFace *)face {
    [self saveSelectedFace:face];
}

@end
