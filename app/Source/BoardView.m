/*  This code is based on Apple's "GeekGameBoard" sample code, version 1.0.
    http://developer.apple.com/samplecode/GeekGameBoard/
    Copyright © 2007 Apple Inc. Copyright © 2008 Jens Alfke. All Rights Reserved.

    Redistribution and use in source and binary forms, with or without modification, are permitted
    provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions
      and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of
      conditions and the following disclaimer in the documentation and/or other materials provided
      with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
    IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND 
    FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRI-
    BUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
    PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
    THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
#import "BoardView.h"
#import "Bit.h"
#import "BitHolder.h"
#import "Game+Protected.h"
#import "Turn.h"
#import "Player.h"
#import "QuartzUtils.h"
#import "GGBUtils.h"


#define kMaxPerspective 0.965   // 55 degrees


@interface BoardView ()
- (void) _findDropTarget: (NSPoint)pos;
@end


@implementation BoardView


@synthesize table=_table, gameBoardInset=_gameBoardInset;


- (void) dealloc
{
    [_game release];
    [super dealloc];
}


#pragma mark -
#pragma mark PERSPECTIVE:


- (void) _applyPerspective
{
    CATransform3D t;
    if( fabs(_perspective) >= M_PI/180 ) {
        CGSize size = self.layer.bounds.size;
        t = CATransform3DMakeTranslation(-size.width/2, -size.height/4, 0);
        t = CATransform3DConcat(t, CATransform3DMakeRotation(-_perspective, 1,0,0));
        
        CATransform3D pers = CATransform3DIdentity;
        pers.m34 = 1.0/-2000;
        t = CATransform3DConcat(t, pers);
        t = CATransform3DConcat(t, CATransform3DMakeTranslation(size.width/2, 
                                                                size.height*(0.25 + 0.05*sin(2*_perspective)),
                                                                0));
        self.layer.borderWidth = 3;
    } else {
        t = CATransform3DIdentity;
        self.layer.borderWidth = 0;
    }
    self.layer.transform = t;
}    

- (CGFloat) perspective {return _perspective;}

- (void) setPerspective: (CGFloat)p
{
    p = MAX(0.0, MIN(kMaxPerspective, p));
    if( p != _perspective ) {
        _perspective = p;
        [self _applyPerspective];
        _game.tablePerspectiveAngle = p;
    }
}

- (IBAction) tiltUp: (id)sender     {self.perspective -= M_PI/40;}
- (IBAction) tiltDown: (id)sender   {self.perspective += M_PI/40;}


#pragma mark -
#pragma mark GAME BOARD:


- (void) _removeGameBoard
{
    if( _table ) {
        RemoveImmediately(_table);
        _table = nil;
    }
}

- (void) createGameBoard
{
    [self _removeGameBoard];
    _table = [[CALayer alloc] init];
    _table.frame = [self gameBoardFrame];
    _table.autoresizingMask = kCALayerMinXMargin | kCALayerMaxXMargin | kCALayerMinYMargin | kCALayerMaxYMargin;
    
    // Tell the game to set up the board:
    _game.tablePerspectiveAngle = _perspective;
    _game.table = _table;

    [self.layer addSublayer: _table];
    [_table release];
}


- (Game*) game
{
    return _game;
}

- (void) setGame: (Game*)game
{
    if( game!=_game ) {
        _game.table = nil;
        setObj(&_game,game);
        [self createGameBoard];
    }
}

- (void) startGameNamed: (NSString*)gameClassName
{
    Class gameClass = NSClassFromString(gameClassName);
    Game *game = [[gameClass alloc] init];
    if( game ) {
        self.game = game;
        [game release];
    }
}


#pragma mark -
#pragma mark VIEW MANIPULATION:


- (CGRect) gameBoardFrame
{
    return CGRectInset(self.layer.bounds, _gameBoardInset.width,_gameBoardInset.height);
}


- (void)resetCursorRects
{
    [super resetCursorRects];
    if( _game.okToMove )
        [self addCursorRect: self.bounds cursor: [NSCursor openHandCursor]];
}


- (NSView*) fullScreenView
{
    return _fullScreenView ?: self;
}

- (IBAction) enterFullScreen: (id)sender
{
    //[self _removeGameBoard];
    if( self.fullScreenView.isInFullScreenMode ) {
        [self.fullScreenView exitFullScreenModeWithOptions: nil];
    } else {
        [self.fullScreenView enterFullScreenMode: self.window.screen 
                                     withOptions: nil];
    }
    //[self createGameBoard];
}


- (void)viewWillStartLiveResize
{
    [super viewWillStartLiveResize];
    _oldSize = self.frame.size;
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize: newSize];
    if( _oldSize.width > 0.0f ) {
        CGAffineTransform xform = _table.affineTransform;
        xform.a = xform.d = MIN(newSize.width,newSize.height)/MIN(_oldSize.width,_oldSize.height);
        BeginDisableAnimations();
        [self _applyPerspective];
        _table.affineTransform = xform;
        EndDisableAnimations();
    } else
        [self createGameBoard];
}

- (void)viewDidEndLiveResize
{
    [super viewDidEndLiveResize];
    _oldSize.width = _oldSize.height = 0.0f;
    [self createGameBoard];
}


#pragma mark -
#pragma mark KEY EVENTS:


- (BOOL) performKeyEquivalent: (NSEvent*)ev
{
    if( [ev.charactersIgnoringModifiers hasPrefix: @"\033"] ) {       // Esc key
        if( self.fullScreenView.isInFullScreenMode ) {
            [self performSelector: @selector(enterFullScreen:) withObject: nil afterDelay: 0.0];
            // without the delayed-perform, NSWindow crashes right after this method returns!
            return YES;
        }
    }
    return NO;
}


#pragma mark -
#pragma mark HIT-TESTING:


/** Converts a point from window coords, to this view's root layer's coords. */
- (CGPoint) _convertPointFromWindowToLayer: (NSPoint)locationInWindow
{
    NSPoint where = [self convertPoint: locationInWindow fromView: nil];    // convert to view coords
    where = [self convertPointToBase: where];                               // then to layer base coords
    return [self.layer convertPoint: NSPointToCGPoint(where)                // then to transformed layer coords
                          fromLayer: self.layer.superlayer];
}


// Hit-testing callbacks (to identify which layers caller is interested in):
typedef BOOL (*LayerMatchCallback)(CALayer*);

static BOOL layerIsBit( CALayer* layer )        {return [layer isKindOfClass: [Bit class]];}
static BOOL layerIsBitHolder( CALayer* layer )  {return [layer conformsToProtocol: @protocol(BitHolder)];}
static BOOL layerIsDropTarget( CALayer* layer ) {return [layer respondsToSelector: @selector(draggingEntered:)];}


/** Locates the layer at a given point in window coords.
    If the leaf layer doesn't pass the layer-match callback, the nearest ancestor that does is returned.
    If outOffset is provided, the point's position relative to the layer is stored into it. */
- (CALayer*) hitTestPoint: (NSPoint)locationInWindow
         forLayerMatching: (LayerMatchCallback)match
                   offset: (CGPoint*)outOffset
{
    CGPoint where = [self _convertPointFromWindowToLayer: locationInWindow ];
    CALayer *layer = [_table hitTest: where];
    while( layer ) {
        if( match(layer) ) {
            CGPoint bitPos = [self.layer convertPoint: layer.position 
                              fromLayer: layer.superlayer];
            if( outOffset )
                *outOffset = CGPointMake( bitPos.x-where.x, bitPos.y-where.y);
            return layer;
        } else
            layer = layer.superlayer;
    }
    return nil;
}


#pragma mark -
#pragma mark MOUSE CLICKS & DRAGS:


- (void) mouseDown: (NSEvent*)ev
{
    if( ! _game.okToMove ) {
        NSBeep();
        return;
    }
    
    BOOL placing = NO;
    _dragStartPos = ev.locationInWindow;
    _dragBit = (Bit*) [self hitTestPoint: _dragStartPos
                        forLayerMatching: layerIsBit 
                                  offset: &_dragOffset];
    
    if( ! _dragBit ) {
        // If no bit was clicked, see if it's a BitHolder the game will let the user add a Bit to:
        id<BitHolder> holder = (id<BitHolder>) [self hitTestPoint: _dragStartPos
                                                 forLayerMatching: layerIsBitHolder
                                                           offset: NULL];
        if( holder ) {
            _dragBit = [_game bitToPlaceInHolder: holder];
            if( _dragBit ) {
                _dragOffset.x = _dragOffset.y = 0;
                if( _dragBit.superlayer==nil )
                    _dragBit.position = [self _convertPointFromWindowToLayer: _dragStartPos];
                placing = YES;
            }
        }
    }
    
    if( ! _dragBit ) {
        Beep();
        return;
    }
    
    // Clicked on a Bit:
    _dragMoved = NO;
    _dropTarget = nil;
    _oldHolder = _dragBit.holder;
    // Ask holder's and game's permission before dragging:
    if( _oldHolder ) {
        _dragBit = [_oldHolder canDragBit: _dragBit];
        if( _dragBit && ! [_game canBit: _dragBit moveFrom: _oldHolder] ) {
            [_oldHolder cancelDragBit: _dragBit];
            _dragBit = nil;
        }
        if( ! _dragBit ) {
            _oldHolder = nil;
            NSBeep();
            return;
        }
    }
    
    // Start dragging:
    _oldSuperlayer = _dragBit.superlayer;
    _oldLayerIndex = [_oldSuperlayer.sublayers indexOfObjectIdenticalTo: _dragBit];
    _oldPos = _dragBit.position;
    ChangeSuperlayer(_dragBit, self.layer, self.layer.sublayers.count);
    _dragBit.pickedUp = YES;
    [[NSCursor closedHandCursor] push];
    
    if( placing ) {
        if( _oldSuperlayer )
            _dragBit.position = [self _convertPointFromWindowToLayer: _dragStartPos];
        _dragMoved = YES;
        [self _findDropTarget: _dragStartPos];
    }
}


- (void) mouseDragged: (NSEvent*)ev
{
    if( _dragBit ) {
        // Get the mouse position, and see if we've moved 3 pixels since the mouseDown:
        NSPoint pos = ev.locationInWindow;
        if( fabs(pos.x-_dragStartPos.x)>=3 || fabs(pos.y-_dragStartPos.y)>=3 )
            _dragMoved = YES;
        
        // Move the _dragBit (without animation -- it's unnecessary and slows down responsiveness):
        CGPoint where = [self _convertPointFromWindowToLayer: pos];
        where.x += _dragOffset.x;
        where.y += _dragOffset.y;
        
        CGPoint newPos = [_dragBit.superlayer convertPoint: where fromLayer: self.layer];

        [CATransaction flush];
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue
                         forKey:kCATransactionDisableActions];
        _dragBit.position = newPos;
        [CATransaction commit];

        // Find what it's over:
        [self _findDropTarget: pos];
    }
}


- (void) _findDropTarget: (NSPoint)locationInWindow
{
    locationInWindow.x += _dragOffset.x;
    locationInWindow.y += _dragOffset.y;
    id<BitHolder> target = (id<BitHolder>) [self hitTestPoint: locationInWindow
                                             forLayerMatching: layerIsBitHolder
                                                       offset: NULL];
    if( target == _oldHolder )
        target = nil;
    if( target != _dropTarget ) {
        [_dropTarget willNotDropBit: _dragBit];
        _dropTarget.highlighted = NO;
        _dropTarget = nil;
    }
    if( target ) {
        CGPoint targetPos = [(CALayer*)target convertPoint: _dragBit.position
                                                 fromLayer: _dragBit.superlayer];
        if( [target canDropBit: _dragBit atPoint: targetPos]
           && [_game canBit: _dragBit moveFrom: _oldHolder to: target] ) {
            _dropTarget = target;
            _dropTarget.highlighted = YES;
        }
    }
}


- (void) mouseUp: (NSEvent*)ev
{
    if( _dragBit ) {
        if( _dragMoved ) {
            // Update the drag tracking to the final mouse position:
            [self mouseDragged: ev];
            _dropTarget.highlighted = NO;
            _dragBit.pickedUp = NO;

            // Is the move legal?
            if( _dropTarget && [_dropTarget dropBit: _dragBit
                                            atPoint: [(CALayer*)_dropTarget convertPoint: _dragBit.position 
                                                                            fromLayer: _dragBit.superlayer]] ) {
                // Yes, notify the interested parties:
                [_oldHolder draggedBit: _dragBit to: _dropTarget];
                [_game bit: _dragBit movedFrom: _oldHolder to: _dropTarget];
            } else {
                // Nope, cancel:
                [_dropTarget willNotDropBit: _dragBit];
                if( _oldSuperlayer ) {
                    ChangeSuperlayer(_dragBit, _oldSuperlayer, _oldLayerIndex);
                    _dragBit.position = _oldPos;
                    [_oldHolder cancelDragBit: _dragBit];
                } else {
                    [_dragBit removeFromSuperlayer];
                }
            }
        } else {
            // Just a click, without a drag:
            _dropTarget.highlighted = NO;
            _dragBit.pickedUp = NO;
            ChangeSuperlayer(_dragBit, _oldSuperlayer, _oldLayerIndex);
            [_oldHolder cancelDragBit: _dragBit];
            if( ! [_game clickedBit: _dragBit] )
                NSBeep();
        }

        _dropTarget = nil;
        _dragBit = nil;
        [NSCursor pop];
    }
}


- (void)scrollWheel:(NSEvent *)e
{
    self.perspective += e.deltaY * M_PI/180;
    //Log(@"Perspective = %2.0f degrees (%5.3f radians)", self.perspective*180/M_PI, self.perspective);
}


#pragma mark -
#pragma mark INCOMING DRAGS:


// subroutine to call the target
static int tell( id target, SEL selector, id arg, int defaultValue )
{
    if( target && [target respondsToSelector: selector] )
        return (ssize_t) [target performSelector: selector withObject: arg];
    else
        return defaultValue;
}


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    _viewDropTarget = [self hitTestPoint: [sender draggingLocation]
                        forLayerMatching: layerIsDropTarget
                                  offset: NULL];
    _viewDropOp = _viewDropTarget ?[_viewDropTarget draggingEntered: sender] :NSDragOperationNone;
    return _viewDropOp;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    CALayer *target = [self hitTestPoint: [sender draggingLocation]
                        forLayerMatching: layerIsDropTarget 
                                  offset: NULL];
    if( target == _viewDropTarget ) {
        if( _viewDropTarget )
            _viewDropOp = tell(_viewDropTarget,@selector(draggingUpdated:),sender,_viewDropOp);
    } else {
        tell(_viewDropTarget,@selector(draggingExited:),sender,0);
        _viewDropTarget = target;
        if( _viewDropTarget )
            _viewDropOp = [_viewDropTarget draggingEntered: sender];
        else
            _viewDropOp = NSDragOperationNone;
    }
    return _viewDropOp;
}

- (BOOL)wantsPeriodicDraggingUpdates
{
    return (_viewDropTarget!=nil);
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    tell(_viewDropTarget,@selector(draggingExited:),sender,0);
    _viewDropTarget = nil;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return tell(_viewDropTarget,@selector(prepareForDragOperation:),sender,YES);
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    return [_viewDropTarget performDragOperation: sender];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
    tell(_viewDropTarget,@selector(concludeDragOperation:),sender,0);
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender
{
    tell(_viewDropTarget,@selector(draggingEnded:),sender,0);
}

@end
