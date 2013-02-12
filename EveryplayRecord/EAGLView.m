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
          // kEAGLColorFormatRGBA8
          // kEAGLColorFormatRGB565
          kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
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
#if USE_EVERYPLAY
    if (everyplayCapture == nil) {
        everyplayCapture = [[EveryplayCapture alloc] initWithView:self eaglContext:context layer:(CAEAGLLayer *)self.layer];
    }
#endif

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

        useMSAA = NO;

        if (useMSAA) {
            glGenFramebuffers(1, &msaaFramebuffer);
            glBindFramebuffer(GL_FRAMEBUFFER, msaaFramebuffer);

            glGenRenderbuffers(1, &msaaColorRenderbuffer);
            glBindRenderbuffer(GL_RENDERBUFFER, msaaColorRenderbuffer);
            glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, 2, GL_RGBA8_OES, framebufferWidth, framebufferHeight);
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, msaaColorRenderbuffer);

            glGenRenderbuffers(1, &msaaDepthRenderbuffer);
            glBindRenderbuffer(GL_RENDERBUFFER, msaaDepthRenderbuffer);
            glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, 2, GL_DEPTH_COMPONENT16, framebufferWidth, framebufferHeight);
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, msaaDepthRenderbuffer);

            glBindRenderbuffer(GL_RENDERBUFFER, msaaColorRenderbuffer);
        }

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        glViewport(0, 0, framebufferWidth, framebufferHeight);

#if USE_EVERYPLAY
        [everyplayCapture createFramebuffer:defaultFramebuffer withMSAA:msaaFramebuffer];
#endif
    }
}

- (void)deleteFramebuffer
{
    if (context) {
        [EAGLContext setCurrentContext:context];

#if USE_EVERYPLAY
        [everyplayCapture deleteFramebuffer];
#endif

        if (defaultFramebuffer) {
            glDeleteFramebuffers(1, &defaultFramebuffer);
            defaultFramebuffer = 0;
        }

        if (colorRenderbuffer) {
            glDeleteRenderbuffers(1, &colorRenderbuffer);
            colorRenderbuffer = 0;
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

#if USE_EVERYPLAY
        if (![everyplayCapture beforePresentRenderbuffer:defaultFramebuffer]) {
#endif
            if (useMSAA) {
                glBindFramebuffer(GL_READ_FRAMEBUFFER_APPLE, msaaFramebuffer);
                glBindFramebuffer(GL_DRAW_FRAMEBUFFER_APPLE, defaultFramebuffer);
                glResolveMultisampleFramebufferAPPLE();

                static const GLenum s_attachments[] = { GL_COLOR_ATTACHMENT0, GL_DEPTH_ATTACHMENT };
                glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, ARRAY_LENGTH(s_attachments), s_attachments);
            } else {
                static const GLenum s_attachments[] = { GL_DEPTH_ATTACHMENT };
                glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, ARRAY_LENGTH(s_attachments), s_attachments);
            }
#if USE_EVERYPLAY
        }
#endif
        
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        success = [context presentRenderbuffer:GL_RENDERBUFFER];
        
#if USE_EVERYPLAY
        if (![everyplayCapture afterPresentRenderbuffer:(useMSAA ? msaaFramebuffer : defaultFramebuffer)]) {
#endif
            if (useMSAA) {
                glBindFramebuffer(GL_FRAMEBUFFER, msaaFramebuffer);
            }
#if USE_EVERYPLAY
        }
#endif
    }
    
    return success;
}

- (void)layoutSubviews
{
    // The framebuffer will be re-created at the beginning of the next setFramebuffer method call.
    [self deleteFramebuffer];
}

@end
