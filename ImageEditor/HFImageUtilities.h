//
//  HFImageUtilities.h
//  ImageEditor
//
//  Created by Yan Cheng on 13-3-8.
//  Copyright (c) 2013年 Heitor Ferreira. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HFImageUtilities : NSObject

+ (UIImage *)scaledImage:(UIImage *)source toSize:(CGSize)size withQuality:(CGInterpolationQuality)quality;
+ (CGImageRef)newScaledImage:(CGImageRef)source withOrientation:(UIImageOrientation)orientation toSize:(CGSize)size withQuality:(CGInterpolationQuality)quality;
+ (CGImageRef)newTransformedImage:(CGAffineTransform)transform
                      sourceImage:(CGImageRef)sourceImage
                       sourceSize:(CGSize)sourceSize
                sourceOrientation:(UIImageOrientation)sourceOrientation
                      outputWidth:(CGFloat)outputWidth
                         cropSize:(CGSize)cropSize
                    imageViewSize:(CGSize)imageViewSize;
@end
