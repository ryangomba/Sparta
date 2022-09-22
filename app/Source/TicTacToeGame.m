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
#import "TicTacToeGame.h"
#import "Grid.h"
#import "Dispenser.h"
#import "Piece.h"
#import "QuartzUtils.h"


@implementation TicTacToeGame

- (Piece*) pieceForPlayer: (int)playerNumber
{
    Piece *p = [[Piece alloc] initWithImageNamed: (playerNumber ? @"O.tiff" :@"X.tiff")
                                           scale: 80];
    p.owner = [self.players objectAtIndex: playerNumber];
    p.name = (playerNumber ?@"O" :@"X");
    return [p autorelease];
}

- (id) init
{
    self = [super init];
    if (self != nil) {
        [self setNumberOfPlayers: 2];
    }
    return self;
}
        
- (void) setUpBoard
{
    // Create a 3x3 grid:
    CGFloat center = floor(CGRectGetMidX(_table.bounds));
    [_grid release];
    _grid = [[RectGrid alloc] initWithRows: 3 columns: 3 frame: CGRectMake(center-150,0, 300,300)];
    [_grid addAllCells];
    _grid.allowsMoves = _grid.allowsCaptures = NO;
    _grid.cellColor = CreateGray(1.0, 0.25);
    _grid.lineColor = kTranslucentLightGrayColor;
    [_table addSublayer: _grid];
}


- (NSString*) stateString
{
    unichar str[10];
    for( int i=0; i<9; i++ ) {
        NSString *ident = [_grid cellAtRow: i/3 column: i%3].bit.name;
        if( ident==nil )
            str[i] = '-';
        else 
            str[i] = [ident characterAtIndex: 0];
    }
    return [NSString stringWithCharacters: str length: 9];
}

- (void) setStateString: (NSString*)stateString
{
    for( int i=0; i<9; i++ ) {
        Piece *piece = nil;
        if( i < stateString.length )
            switch( [stateString characterAtIndex: i] ) {
                case 'X': case 'x': piece = [self pieceForPlayer: 0]; break;
                case 'O': case 'o': piece = [self pieceForPlayer: 1]; break;
                default:            break;
            }
        [_grid cellAtRow: i/3 column: i%3].bit = piece;
    }
}


- (Bit*) bitToPlaceInHolder: (id<BitHolder>)holder
{
    if( holder.bit==nil && [holder isKindOfClass: [Square class]] )
        return [self pieceForPlayer: self.currentPlayer.index];
    else
        return nil;
}


- (void) bit: (Bit*)bit movedFrom: (id<BitHolder>)src to: (id<BitHolder>)dst
{
    Square *square = (Square*)dst;
    int squareIndex = 3*square.row + square.column;
    [self.currentTurn addToMove: [NSString stringWithFormat: @"%@%i", bit.name, squareIndex]];
    [super bit: bit movedFrom: src to: dst];
}

static Player* ownerAt( Grid *grid, int index )
{
    return [grid cellAtRow: index/3 column: index%3].bit.owner;
}

/** Should return the winning player, if the current position is a win. */
- (Player*) checkForWinner
{
    static const int kWinningTriples[8][3] =  { {0,1,2}, {3,4,5}, {6,7,8},  // rows
                                                {0,3,6}, {1,4,7}, {2,5,8},  // cols
                                                {0,4,8}, {2,4,6} };         // diagonals
    for( int i=0; i<8; i++ ) {
        const int *triple = kWinningTriples[i];
        Player *p = ownerAt(_grid,triple[0]);
        if( p && p == ownerAt(_grid,triple[1]) && p == ownerAt(_grid,triple[2]) )
            return p;
    }
    return nil;
}

@end
