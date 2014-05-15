/*
 * Copyright 2013 Applifier
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import <QuartzCore/QuartzCore.h>
#import "EAGLView.h"

#define USE_16bit 0

#define USE_MSAA 0

#if USE_16bit
#define colorFormatLayer kEAGLColorFormatRGB565
#define colorFormat GL_RGB565
#else
#define colorFormatLayer kEAGLColorFormatRGBA8
#define colorFormat GL_RGBA8_OES
#endif

@interface EAGLView (PrivateMethods)
- (void)createFramebuffer;
- (void)deleteFramebuffer;
@end

@implementation EAGLView

@dynamic context;

// You must implement this method
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

//The EAGL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:.
- (id)initWithCoder:(NSCoder*)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;

        eaglLayer.contentsScale = [[UIScreen mainScreen] scale];
        eaglLayer.opaque = TRUE;
        eaglLayer.drawableProperties = @{
          kEAGLDrawablePropertyRetainedBacking: [NSNumber numberWithBool:FALSE],
          kEAGLDrawablePropertyColorFormat: colorFormatLayer
        };
    }

    return self;
}

- (void)dealloc
{
    [self deleteFramebuffer];
}

- (EAGLContext *)context
{
    return context;
}

- (void)setContext:(EAGLContext *)newContext
{
    if (context != newContext) {
        [self deleteFramebuffer];

        context = newContext;

        [EAGLContext setCurrentContext:nil];
    }
}

- (GLfloat)aspect
{
    if (!framebufferHeight) return 0.0;

    return ((GLfloat) framebufferWidth) / ((GLfloat) framebufferHeight);
}

- (void)createFramebuffer
{
    if (context && !defaultFramebuffer) {
        // Create default framebuffer object.
        glGenFramebuffers(1, &defaultFramebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);

        // Create color render buffer and allocate backing store.
        glGenRenderbuffers(1, &colorRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &framebufferWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &framebufferHeight);

        // Attach color render buffer
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);

        // Create depth render buffer and allocate backing store.
        glGenRenderbuffers(1, &depthRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, framebufferWidth, framebufferHeight);

        // Attach depth render buffer
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);

#if USE_MSAA
        useMSAA = YES;
#else
        useMSAA = NO;
#endif

        if (useMSAA) {
            glGenFramebuffers(1, &msaaFramebuffer);
            glBindFramebuffer(GL_FRAMEBUFFER, msaaFramebuffer);

            glGenRenderbuffers(1, &msaaColorRenderbuffer);
            glBindRenderbuffer(GL_RENDERBUFFER, msaaColorRenderbuffer);
            if ([context API] >= kEAGLRenderingAPIOpenGLES3) {
                glRenderbufferStorageMultisample(GL_RENDERBUFFER, 2, colorFormat, framebufferWidth, framebufferHeight);
            } else {
                glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, 2, colorFormat, framebufferWidth, framebufferHeight);
            }
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, msaaColorRenderbuffer);

            glGenRenderbuffers(1, &msaaDepthRenderbuffer);
            glBindRenderbuffer(GL_RENDERBUFFER, msaaDepthRenderbuffer);
            if ([context API] >= kEAGLRenderingAPIOpenGLES3) {
                glRenderbufferStorageMultisample(GL_RENDERBUFFER, 2, GL_DEPTH_COMPONENT16, framebufferWidth, framebufferHeight);
            } else {
                glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, 2, GL_DEPTH_COMPONENT16, framebufferWidth, framebufferHeight);
            }
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, msaaDepthRenderbuffer);

            glBindRenderbuffer(GL_RENDERBUFFER, msaaColorRenderbuffer);
        }

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        glViewport(0, 0, framebufferWidth, framebufferHeight);
    }
}

- (void)deleteFramebuffer
{
    if (context) {
        [EAGLContext setCurrentContext:context];

        if (msaaFramebuffer) {
            glDeleteFramebuffers(1, &msaaFramebuffer);
            msaaFramebuffer = 0;
        }

        if (defaultFramebuffer) {
            glDeleteFramebuffers(1, &defaultFramebuffer);
            defaultFramebuffer = 0;
        }

        if (msaaColorRenderbuffer) {
            glDeleteRenderbuffers(1, &msaaColorRenderbuffer);
            msaaColorRenderbuffer = 0;
        }

        if (colorRenderbuffer) {
            glDeleteRenderbuffers(1, &colorRenderbuffer);
            colorRenderbuffer = 0;
        }

        if (msaaDepthRenderbuffer) {
            glDeleteRenderbuffers(1, &msaaDepthRenderbuffer);
            msaaDepthRenderbuffer = 0;
        }

        if (depthRenderbuffer) {
            glDeleteRenderbuffers(1, &depthRenderbuffer);
            depthRenderbuffer = 0;
        }
    }
}

- (void)setFramebuffer
{
    if (context) {
        [EAGLContext setCurrentContext:context];

        if (!defaultFramebuffer)
            [self createFramebuffer];
    }
}

- (BOOL)presentFramebuffer
{
    BOOL success = FALSE;

    if (context) {
        [EAGLContext setCurrentContext:context];

#define ARRAY_LENGTH(X) (sizeof(X) / sizeof((X)[0]))

        if (useMSAA) {
            glBindFramebuffer(GL_READ_FRAMEBUFFER_APPLE, msaaFramebuffer);
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER_APPLE, defaultFramebuffer);

            static const GLenum s_attachments[] = { GL_COLOR_ATTACHMENT0, GL_DEPTH_ATTACHMENT };

            if ([context API] >= kEAGLRenderingAPIOpenGLES3) {
                glBlitFramebuffer(0, 0, framebufferWidth, framebufferHeight,
                                  0, 0, framebufferWidth, framebufferHeight,
                                  GL_COLOR_BUFFER_BIT, GL_NEAREST);
                glInvalidateFramebuffer(GL_READ_FRAMEBUFFER_APPLE, ARRAY_LENGTH(s_attachments), s_attachments);
            } else {
                glResolveMultisampleFramebufferAPPLE();
                glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, ARRAY_LENGTH(s_attachments), s_attachments);
            }
        } else {
            static const GLenum s_attachments[] = { GL_DEPTH_ATTACHMENT };
            if ([context API] >= kEAGLRenderingAPIOpenGLES3) {
                glInvalidateFramebuffer(GL_READ_FRAMEBUFFER_APPLE, ARRAY_LENGTH(s_attachments), s_attachments);
            } else {
                glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, ARRAY_LENGTH(s_attachments), s_attachments);
            }
        }
        
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        success = [context presentRenderbuffer:GL_RENDERBUFFER];
        
        if (useMSAA) {
            glBindFramebuffer(GL_FRAMEBUFFER, msaaFramebuffer);
        }
    }
    
    return success;
}

- (void)layoutSubviews
{
    // The framebuffer will be re-created at the beginning of the next setFramebuffer method call.
    [self deleteFramebuffer];
}

@end
