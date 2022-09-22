//
//  iPhoneAppDelegate.m
//  GGB-iPhone
//
//  Created by Jens Alfke on 3/7/08.
//  Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import "iPhoneAppDelegate.h"
#import "BoardUIView.h"
#import "Game.h"
#import "Player.h"
#import "QuartzUtils.h"
#import "GGBUtils.h"


#if 0
// Temporary HACK to fix logging problem in beta 6 iPhone OS
extern void _NSSetLogCStringFunction(void (*)(const char *string, unsigned length, BOOL withSyslogBanner));
static void PrintNSLogMessage(const char *string, unsigned length, BOOL withSyslogBanner)
{
	puts(string);
}
static void HackNSLog(void) __attribute__((constructor));
static void HackNSLog(void)
{
	_NSSetLogCStringFunction(PrintNSLogMessage);
}
#endif


@implementation GGB_iPhoneAppDelegate


@synthesize window=_window;
@synthesize contentView=_contentView;
@synthesize headline=_headline;


- (void)applicationDidFinishLaunching:(UIApplication *)application 
{	
    // Create window
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    _window.layer.backgroundColor = GetCGPatternNamed(@"Background.png");
    
    // Set up content view
    CGRect rHeadline,rContent;
    CGRectDivide([[UIScreen mainScreen] applicationFrame],
                 &rHeadline, &rContent, 35, CGRectMinYEdge);
    
    self.contentView = [[[BoardUIView alloc] initWithFrame: rContent] autorelease];
    [_window addSubview: _contentView];
    
    self.headline = [[[UILabel alloc] initWithFrame: rHeadline] autorelease];
    _headline.backgroundColor = nil;
    _headline.opaque = NO;
    _headline.textAlignment = UITextAlignmentCenter;
    _headline.font = [UIFont boldSystemFontOfSize: 20];
    _headline.minimumFontSize = 14;
    _headline.adjustsFontSizeToFitWidth = YES;
    [_window addSubview: _headline];
    
    // Start game:
    [self startGameNamed: @"CheckersGame"];
    
    // Show window
    [_window makeKeyAndVisible];
}


- (void)dealloc 
{
    [_contentView release];
    [_headline release];
    [_window release];
    [super dealloc];
}


- (void) startGameNamed: (NSString*)gameClassName
{
    Game *game = _contentView.game;
    [game removeObserver: self  forKeyPath: @"currentPlayer"];
    [game removeObserver: self forKeyPath: @"winner"];
    
    if( gameClassName == nil )
        gameClassName = [[game class] description];
    
    [_contentView startGameNamed: gameClassName];
    
    game = _contentView.game;
    [game addObserver: self 
           forKeyPath: @"currentPlayer"
              options: NSKeyValueObservingOptionInitial
              context: NULL];
    [game addObserver: self
           forKeyPath: @"winner"
              options: 0 
              context: NULL];
}


- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change
                       context:(void *)context
{
    Game *game = _contentView.game;
    if( object == game ) {
        Player *p = game.winner;
        NSString *msg;
        if( p ) {
            PlaySound(@"Sosumi");
            msg = @"%@ wins!";
        } else {
            p = game.currentPlayer;
            msg = @"Your turn, %@";
        }
        _headline.text = [NSString stringWithFormat: msg, p.name];
        
        if( game.winner ) {
            UIAlertView *alert;
            alert = [[UIAlertView alloc] initWithTitle: msg
                                               message: @"Congratulations!"
                                              delegate:self
                                     cancelButtonTitle:nil 
                                     otherButtonTitles:nil];
            [alert show];
            [alert release];
        }            
    }
}


- (void)alertView:(UIAlertView *)modalView didDismissWithButtonIndex:(NSInteger)buttonIndex;
{
    // Start new game:
    [self startGameNamed: nil];
}


@end
