#import "FaceEditingViewController.h"

@interface FaceEditingViewController ()
@property (nonatomic, retain, direct) NTKFace *face;
@property (nullable, nonatomic, retain, direct) NTKFaceViewController *faceViewController;
@property (nonatomic, direct) BOOL editingStarted;
@property (nonatomic, direct) BOOL finishing;
@end

@implementation FaceEditingViewController

- (instancetype)initWithFace:(NTKFace *)face {
    self = [super init];
    if (self != nil) {
        self.face = face;
    }
    return self;
}

- (void)dealloc {
    [_faceViewController release];
    [_face release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self configureNavigation];
    [self configureFaceViewController];
}

- (void)configureNavigation __attribute__((objc_direct)) {
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(didSelectDone:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    [doneButton release];
}

- (void)configureFaceViewController __attribute__((objc_direct)) {
    NTKFaceViewController *faceViewController = [[NTKFaceViewController alloc] initWithFace:self.face configuration:nil];
    [self addChildViewController:faceViewController];
    faceViewController.view.frame = self.view.bounds;
    faceViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:faceViewController.view];
    [faceViewController didMoveToParentViewController:self];
    self.faceViewController = faceViewController;
    [faceViewController release];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self beginEditingIfNeeded];
}

- (void)beginEditingIfNeeded __attribute__((objc_direct)) {
    if (self.editingStarted || self.faceViewController == nil) return;
    self.editingStarted = YES;
    [self.faceViewController showEditingUIAnimated:YES fromZoomLevel:0];
}

- (void)didSelectDone:(UIBarButtonItem *)sender {
    NTKFaceViewController * _Nullable faceViewController = self.faceViewController;
    if (self.finishing || faceViewController == nil || ![faceViewController canStopEditing]) return;
    self.finishing = YES;
    [faceViewController hideFaceEditingUIAnimated:YES destination:0 completion:^{
        id<FaceEditingViewControllerDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(faceEditingViewController:didFinishEditingFace:)]) {
            [delegate faceEditingViewController:self didFinishEditingFace:self.face];
        }
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
}

@end
