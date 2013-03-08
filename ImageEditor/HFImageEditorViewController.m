#import "HFImageEditorViewController.h"
#import "HFImageUtilities.h"

static const CGFloat kMaxUIImageSize = 1024;
static const CGFloat kPreviewImageSize = 120;
static const CGFloat kDefaultCropWidth = 320;
static const CGFloat kDefaultCropHeight = 320;
static const CGFloat kBoundingBoxInset = 15;
static const NSTimeInterval kAnimationIntervalReset = 0.25;
static const NSTimeInterval kAnimationIntervalTransform = 0.35;

@interface HFImageEditorViewController ()
@property (nonatomic,retain) UIImageView *imageView;
@property (nonatomic,assign) CGRect cropRect;
@property (retain, nonatomic) IBOutlet UIPanGestureRecognizer *panRecognizer;
@property (retain, nonatomic) IBOutlet UIRotationGestureRecognizer *rotationRecognizer;
@property (retain, nonatomic) IBOutlet UIPinchGestureRecognizer *pinchRecognizer;
@property (retain, nonatomic) IBOutlet UITapGestureRecognizer *tapRecognizer;
@property (nonatomic,retain) IBOutlet UIView<HFImageEditorFrame> *frameView;


@property(nonatomic,assign) NSUInteger gestureCount;
@property(nonatomic,assign) CGPoint touchCenter;
@property(nonatomic,assign) CGPoint rotationCenter;
@property(nonatomic,assign) CGPoint scaleCenter;
@property(nonatomic,assign) CGFloat scale;

@end



@implementation HFImageEditorViewController

@synthesize doneCallback = _doneCallback;
@synthesize sourceImage = _sourceImage;
@synthesize previewImage = _previewImage;
@synthesize cropSize = _cropSize;
@synthesize outputWidth = _outputWidth;
@synthesize frameView = _frameView;
@synthesize imageView = _imageView;
@synthesize panRecognizer = _panRecognizer;
@synthesize rotationRecognizer = _rotationRecognizer;
@synthesize tapRecognizer = _tapRecognizer;
@synthesize pinchRecognizer = _pinchRecognizer;
@synthesize touchCenter = _touchCenter;
@synthesize rotationCenter = _rotationCenter;
@synthesize scaleCenter = _scaleCenter;
@synthesize scale = _scale;
@synthesize minimumScale = _minimumScale;
@synthesize maximumScale = _maximumScale;
@synthesize gestureCount = _gestureCount;

@dynamic panEnabled;
@dynamic rotateEnabled;
@dynamic scaleEnabled;
@dynamic tapToResetEnabled;

@synthesize limitedSizeEnabled=_limitedSizeEnabled;

@dynamic cropBoundsInSourceImage;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if(self) {
        _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _rotationRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotation:)];
        _pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
        _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    
        _limitedSizeEnabled=NO;
        
    }
    return self;
}

- (void) dealloc
{
    [_panRecognizer removeTarget:self action:@selector(handlePan:)];
    [_frameView removeGestureRecognizer:_panRecognizer];
    
    [_pinchRecognizer removeTarget:self action:@selector(handlePinch:)];
    [_frameView removeGestureRecognizer:_pinchRecognizer];
    
    [_tapRecognizer removeTarget:self action:@selector(handleTap:)];
    [_frameView removeGestureRecognizer:_tapRecognizer];
    
    [_rotationRecognizer removeTarget:self action:@selector(handleRotation:)];
    [_frameView removeGestureRecognizer:_rotationRecognizer];
    
}

#pragma mark Properties

- (void)setCropSize:(CGSize)cropSize
{
    _cropSize = cropSize;
        
    [self updateCropRect];
}

- (CGSize)cropSize
{
//    if(_cropSize.width == 0 || _cropSize.height == 0) {
//        _cropSize = CGSizeMake(kDefaultCropWidth, kDefaultCropHeight);
//    }
    return _cropSize;
}

- (UIImage *)previewImage
{
    if(_previewImage == nil && _sourceImage != nil) {
        if(self.sourceImage.size.height > kMaxUIImageSize || self.sourceImage.size.width > kMaxUIImageSize) {
            CGFloat aspect = self.sourceImage.size.height/self.sourceImage.size.width;
            CGSize size;
            if(aspect >= 1.0) { //square or portrait
                size = CGSizeMake(kPreviewImageSize,kPreviewImageSize*aspect);
            } else { // landscape
                size = CGSizeMake(kPreviewImageSize,kPreviewImageSize*aspect);
            }
            _previewImage = [HFImageUtilities scaledImage:self.sourceImage  toSize:size withQuality:kCGInterpolationLow];
        } else {
            _previewImage = _sourceImage;
        }
    }
    return  _previewImage;
}

- (void)setSourceImage:(UIImage *)sourceImage
{
    if(sourceImage != _sourceImage) {
        _sourceImage = sourceImage;
        self.previewImage = nil;
    }
}


- (void)updateCropRect
{
    if(!CGSizeEqualToSize(self.cropSize, CGSizeZero)){
        self.cropRect = CGRectMake((self.frameView.bounds.size.width-self.cropSize.width)/2,
                               (self.frameView.bounds.size.height-self.cropSize.height)/2,
                               self.cropSize.width, self.cropSize.height);
    
        self.frameView.cropRect = self.cropRect;
    }
    else {
        self.cropRect=self.frameView.bounds;
        self.frameView.cropRect=self.cropRect;
    }
}


- (void)setPanEnabled:(BOOL)panEnabled
{
    self.panRecognizer.enabled = panEnabled;
}

- (BOOL)panEnabled
{
    return self.panRecognizer.enabled;
}

- (void)setScaleEnabled:(BOOL)scaleEnabled
{
    self.pinchRecognizer.enabled = scaleEnabled;
}

- (BOOL)scaleEnabled
{
    return self.pinchRecognizer.enabled;
}


- (void)setRotateEnabled:(BOOL)rotateEnabled
{
    self.rotationRecognizer.enabled = rotateEnabled;
}

- (BOOL)rotateEnabled
{
    return self.rotationRecognizer.enabled;
}

- (void)setTapToResetEnabled:(BOOL)tapToResetEnabled
{
    self.tapRecognizer.enabled = tapToResetEnabled;
}

- (BOOL)tapToResetEnabled
{
    return self.tapToResetEnabled;
}

#pragma mark Public methods
-(void)reset:(BOOL)animated
{
    CGFloat aspect = self.sourceImage.size.height/self.sourceImage.size.width;
    CGFloat w = CGRectGetWidth(self.cropRect);
    CGFloat h = aspect * w;
    
    if(_limitedSizeEnabled && !CGSizeEqualToSize(self.cropSize, CGSizeZero) &&  h<self.cropRect.size.height){
        h=CGRectGetHeight(self.cropRect);
        w=h/aspect;
    }
    
    self.scale = 1;
    
    void (^doReset)(void) = ^{
        self.imageView.transform = CGAffineTransformIdentity;
        //self.imageView.frame=CGRectMake(0,0,w,h);
        self.imageView.frame = CGRectMake(CGRectGetMidX(self.cropRect) - w/2, CGRectGetMidY(self.cropRect) - h/2,w,h);
        //self.imageView.transform=CGAffineTransformTranslate(self.imageView.transform, CGRectGetMidX(self.cropRect) - w/2, CGRectGetMidY(self.cropRect) - h/2);
        
        NSLog(@"init image is %@",NSStringFromCGRect(self.imageView.frame));
        NSLog(@"init transform is %@",NSStringFromCGAffineTransform(self.imageView.transform));
    };
    if(animated) {
        self.view.userInteractionEnabled = NO;
        [UIView animateWithDuration:kAnimationIntervalReset animations:doReset completion:^(BOOL finished) {
            self.view.userInteractionEnabled = YES;
        }];
    } else {
        doReset();
    }
    
    
}

#pragma mark View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.imageView = [[UIImageView alloc] init];
    [self.view insertSubview:self.imageView belowSubview:self.frameView];
    
    [self.view setMultipleTouchEnabled:YES];

    self.panRecognizer.cancelsTouchesInView = NO;
    self.panRecognizer.delegate = self;
    [self.frameView addGestureRecognizer:self.panRecognizer];
    self.rotationRecognizer.cancelsTouchesInView = NO;
    self.rotationRecognizer.delegate = self;
    [self.frameView addGestureRecognizer:self.rotationRecognizer];
    self.pinchRecognizer.cancelsTouchesInView = NO;
    self.pinchRecognizer.delegate = self;
    [self.frameView addGestureRecognizer:self.pinchRecognizer];
    self.tapRecognizer.numberOfTapsRequired = 2;
    [self.frameView addGestureRecognizer:self.tapRecognizer];
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [self setFrameView:nil];
    [self setImageView:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateCropRect];
    [self reset:NO];
    self.imageView.image = self.previewImage;
    
    if(self.previewImage != self.sourceImage) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            CGImageRef hiresCGImage = NULL;
            CGFloat aspect = self.sourceImage.size.height/self.sourceImage.size.width;
            CGSize size;
            if(aspect >= 1.0) { //square or portrait
                size = CGSizeMake(kMaxUIImageSize*aspect,kMaxUIImageSize);
            } else { // landscape
                size = CGSizeMake(kMaxUIImageSize,kMaxUIImageSize*aspect);
            }
            hiresCGImage = [HFImageUtilities newScaledImage:self.sourceImage.CGImage withOrientation:self.sourceImage.imageOrientation toSize:size withQuality:kCGInterpolationDefault];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.imageView.image = [UIImage imageWithCGImage:hiresCGImage scale:1.0 orientation:UIImageOrientationUp];
                CGImageRelease(hiresCGImage);
            });
        });
    }
}

#pragma mark Actions

- (IBAction)resetAction:(id)sender
{
    [self reset:NO];
}

- (IBAction)resetAnimatedAction:(id)sender
{
    [self reset:YES];
}


- (IBAction)doneAction:(id)sender
{
    self.view.userInteractionEnabled = NO;
    [self startTransformHook];
    if(CGSizeEqualToSize(self.cropSize, CGSizeZero)){
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            UIImage *transform=self.sourceImage;
            self.view.userInteractionEnabled = YES;
            if(self.doneCallback) {
                self.doneCallback(transform, NO);
            }
            [self endTransformHook];
        });
    }
    else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            CGImageRef resultRef = [HFImageUtilities newTransformedImage:self.imageView.transform
                                                 sourceImage:self.sourceImage.CGImage
                                                  sourceSize:self.sourceImage.size
                                           sourceOrientation:self.sourceImage.imageOrientation
                                                 outputWidth:self.outputWidth ? self.outputWidth : self.sourceImage.size.width
                                                    cropSize:self.cropSize
                                               imageViewSize:self.imageView.bounds.size];
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *transform =  [UIImage imageWithCGImage:resultRef scale:1.0 orientation:UIImageOrientationUp];
                CGImageRelease(resultRef);
                self.view.userInteractionEnabled = YES;
                if(self.doneCallback) {
                    self.doneCallback(transform, NO);
                }
                [self endTransformHook];
            });
        });
    }

}


- (IBAction)cancelAction:(id)sender
{
    if(self.doneCallback) {
        self.doneCallback(nil, YES);
    }
}

#pragma mark Touches

- (void)handleTouches:(NSSet*)touches
{
    self.touchCenter = CGPointZero;
    if(touches.count < 2) return;
    
    [touches enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        UITouch *touch = (UITouch*)obj;
        CGPoint touchLocation = [touch locationInView:self.imageView];
        self.touchCenter = CGPointMake(self.touchCenter.x + touchLocation.x, self.touchCenter.y +touchLocation.y);
    }];
    self.touchCenter = CGPointMake(self.touchCenter.x/touches.count, self.touchCenter.y/touches.count);
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self handleTouches:[event allTouches]];
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self handleTouches:[event allTouches]];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
   [self handleTouches:[event allTouches]];
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
   [self handleTouches:[event allTouches]];
}

#pragma mark Gestures
-(BOOL) _scaleMe
{
    BOOL ret = NO;
    
    CGFloat scale = self.scale;
    if(self.minimumScale != 0 && self.scale < self.minimumScale) {
        scale = self.minimumScale;
    } else if(self.maximumScale != 0 && self.scale > self.maximumScale) {
        scale = self.maximumScale;
    }
    
    if( _limitedSizeEnabled && !CGSizeEqualToSize(self.cropSize, CGSizeZero) && 
        (self.imageView.frame.size.width<self.cropRect.size.width||self.imageView.frame.size.height<self.cropRect.size.height) ){
        
        CGFloat xx =self.cropRect.size.width/self.imageView.bounds.size.width;
        CGFloat yy =self.cropRect.size.height/self.imageView.bounds.size.height;
        scale = MAX(xx,yy);
    }
    
    if(scale != self.scale) {
        CGFloat deltaX = self.scaleCenter.x-self.imageView.bounds.size.width/2.0;
        CGFloat deltaY = self.scaleCenter.y-self.imageView.bounds.size.height/2.0;
        
        CGAffineTransform transform =  CGAffineTransformTranslate(self.imageView.transform, deltaX, deltaY);
        transform = CGAffineTransformScale(transform, scale/self.scale , scale/self.scale);
        transform = CGAffineTransformTranslate(transform, -deltaX, -deltaY);
        self.view.userInteractionEnabled = NO;
        [UIView animateWithDuration:kAnimationIntervalTransform delay:0 options:UIViewAnimationCurveEaseOut animations:^{
            self.imageView.transform = transform;
        } completion:^(BOOL finished) {
            self.view.userInteractionEnabled = YES;
            self.scale = scale;
            
            if(_limitedSizeEnabled)
                [self _translateMe];
        }];
        
        ret=YES;
    }
    return ret;
}
-(BOOL) _translateMe
{
    BOOL ret=NO;
    
    if(!_limitedSizeEnabled || CGSizeEqualToSize(self.cropSize, CGSizeZero)) return NO;
    
    CGFloat minX=self.cropRect.origin.x+self.cropRect.size.width-self.imageView.frame.size.width;
    CGFloat maxX=self.cropRect.origin.x;
    CGFloat minY=self.cropRect.origin.y+self.cropRect.size.height-self.imageView.frame.size.height;
    CGFloat maxY=self.cropRect.origin.y;
    
    CGFloat dx =MAX(minX, MIN(self.imageView.frame.origin.x,maxX));
    CGFloat dy =MAX(minY, MIN(self.imageView.frame.origin.y,maxY));
    
    if(dx!=self.imageView.frame.origin.x || dy!=self.imageView.frame.origin.y) {
        
        self.view.userInteractionEnabled = NO;
        [UIView animateWithDuration: kAnimationIntervalTransform delay:0 options:UIViewAnimationCurveEaseOut animations:^{
            
            CGAffineTransform transform=self.imageView.transform;
            
            float ox = self.imageView.frame.origin.x-transform.tx;
            float oy = self.imageView.frame.origin.y-transform.ty;
            transform=CGAffineTransformTranslate(transform, -1.f*transform.tx,-1.f*transform.ty);
            
            float rtx=(ox+transform.tx-dx)/transform.a;
            float rty=(oy+transform.ty-dy)/transform.d;
            transform=CGAffineTransformTranslate(transform, -1.f*rtx,-1.f*rty);
            
            self.imageView.transform=transform;
            
        } completion:^(BOOL finished) {
            self.view.userInteractionEnabled = YES;
            
        }];
        
        ret=YES;
    }
    return ret;
}
- (BOOL)handleGestureState:(UIGestureRecognizerState)state
{
    BOOL handle = YES;
    switch (state) {
        case UIGestureRecognizerStateBegan:
            self.gestureCount++;
            break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded: {
            self.gestureCount--;
            handle = NO;
            if(self.gestureCount == 0) {
                if(![self _scaleMe])
                    [self _translateMe];
            }
        } break;
        default:
            break;
    }
    return handle;
}


- (IBAction)handlePan:(UIPanGestureRecognizer*)recognizer
{
    //if(CGSizeEqualToSize(self.cropSize, CGSizeZero)) return;
    
    if([self handleGestureState:recognizer.state]) {
        CGPoint translation = [recognizer translationInView:self.imageView];
        CGAffineTransform transform = CGAffineTransformTranslate( self.imageView.transform, translation.x, translation.y);
        self.imageView.transform = transform;
        
        [recognizer setTranslation:CGPointMake(0, 0) inView:self.frameView];
    }

}

- (IBAction)handleRotation:(UIRotationGestureRecognizer*)recognizer
{
    if([self handleGestureState:recognizer.state]) {
        if(recognizer.state == UIGestureRecognizerStateBegan){
            self.rotationCenter = self.touchCenter;
        } 
        CGFloat deltaX = self.rotationCenter.x-self.imageView.bounds.size.width/2;
        CGFloat deltaY = self.rotationCenter.y-self.imageView.bounds.size.height/2;

        CGAffineTransform transform =  CGAffineTransformTranslate(self.imageView.transform,deltaX,deltaY);
        transform = CGAffineTransformRotate(transform, recognizer.rotation);
        transform = CGAffineTransformTranslate(transform, -deltaX, -deltaY);
        self.imageView.transform = transform;

        recognizer.rotation = 0;
    }

}

- (IBAction)handlePinch:(UIPinchGestureRecognizer *)recognizer
{
    if([self handleGestureState:recognizer.state]) {
        if(recognizer.state == UIGestureRecognizerStateBegan){
            self.scaleCenter = self.touchCenter;
        } 
        CGFloat deltaX = self.scaleCenter.x-self.imageView.bounds.size.width/2.0;
        CGFloat deltaY = self.scaleCenter.y-self.imageView.bounds.size.height/2.0;

        CGAffineTransform transform =  CGAffineTransformTranslate(self.imageView.transform, deltaX, deltaY);
        transform = CGAffineTransformScale(transform, recognizer.scale, recognizer.scale);
        transform = CGAffineTransformTranslate(transform, -deltaX, -deltaY);
        self.scale *= recognizer.scale;
        self.imageView.transform = transform;

        NSLog(@"pin:--trans is %@,frame is %@",NSStringFromCGAffineTransform(transform),NSStringFromCGRect(self.imageView.frame));
        
        recognizer.scale = 1;
    }
}

- (IBAction)handleTap:(UITapGestureRecognizer *)recogniser {
    [self reset:YES];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}



- (CGRect)cropBoundsInSourceImage
{
    CGAffineTransform uiCoords = CGAffineTransformMakeScale(self.sourceImage.size.width/self.imageView.bounds.size.width,
                                                            self.sourceImage.size.height/self.imageView.bounds.size.height);
    uiCoords = CGAffineTransformTranslate(uiCoords, self.imageView.bounds.size.width/2.0, self.imageView.bounds.size.height/2.0);
    uiCoords = CGAffineTransformScale(uiCoords, 1.0, -1.0);

    CGRect crop =  CGRectMake(-self.cropSize.width/2.0, -self.cropSize.height/2.0, self.cropSize.width, self.cropSize.height);
    return CGRectApplyAffineTransform(crop, CGAffineTransformConcat(CGAffineTransformInvert(self.imageView.transform),uiCoords));
}


#pragma mark Subclass Hooks

- (void)startTransformHook
{
}

- (void)endTransformHook
{
}



@end
