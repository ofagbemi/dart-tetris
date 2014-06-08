import 'dart:html';
import 'dart:math';

const String BACKGROUND_COLOR = "white";
const int BLOCK_GAP = 2;
const num STEP_TIME = 400;
var rng = new Random();

final List<String> COLORS = ["rgba(159,187,159,0.5)", "rgba(90,196,255,0.5)",
                             "rgba(255,178,36,0.5)", "rgba(148,103,148,0.5)",
                             "rgba(194,66,66,0.5)"];
const int LONG_INDEX = 1;
final List<List<List<int>>> SHAPES = [
  [[1,1,0,0],
   [1,1,0,0],
   [0,0,0,0],
   [0,0,0,0]],
   
   // long: index 1
   [[1,0,0,0],
    [1,0,0,0],
    [1,0,0,0],
    [1,0,0,0]],

   [[0,1,1,0],
    [1,1,0,0],
    [0,0,0,0],
    [0,0,0,0]],

   [[1,1,0,0],
    [0,1,1,0],
    [0,0,0,0],
    [0,0,0,0]],
    
   [[1,0,0,0],
    [1,0,0,0],
    [1,1,0,0],
    [0,0,0,0]],

   [[0,1,0,0],
    [0,1,0,0],
    [1,1,0,0],
    [0,0,0,0]],
    
   [[1,1,1,0],
    [0,1,0,0],
    [0,0,0,0],
    [0,0,0,0]]
];

void main() {
  CanvasElement canvas = querySelector("#area");
  CanvasElement showNextCanvas = querySelector("#show-next");
  
  int numBlocksX = 11;
  
  Tetris t = new Tetris(canvas, showNextCanvas, numBlocksX);
  
  DivElement startOver = querySelector(".button.start-over");
  startOver.onClick.listen((e) {
    t.stop();
    t = new Tetris(canvas, showNextCanvas, numBlocksX);
    t.start();
  });
  
  t.start();
}

class Tetris {
  CanvasElement canvas;
  CanvasElement showNextCanvas;
  
  bool gameOver = false;
  
  int score = 0;
  
  var scoreBox = querySelector("#score-box");
  
  int turn = 0;
  
  // the currently moving block
  Block activeBlock;
  
  int currentColor = 0;
  
  //
  List<Block> blocksQueue;
  
  // width and height of the canvas
  num width;
  num height;
  
  // number of bricks along each axis
  int numBricksX;
  int numBricksY;
  
  // size in pixels of one block
  num brickWidth;
  
  // time to render frame
  num renderTime;
  
  // Two dimensional array of bricks
  // does NOT include the active block
  List<List<Brick>> bricks;
  
  Tetris(CanvasElement c, CanvasElement sn, int nbx) {
    canvas = c;
    showNextCanvas = sn;
    numBricksX = nbx;
    blocksQueue = new List<Block>();
  }
  
  // Converts game position point to
  // pixel position point
  Point getPointFromXY(int x, int y) {
    return new Point(x*brickWidth, y*brickWidth);
  }
  
  void showNext() {
    drawBackground(showNextCanvas.context2D);
    blocksQueue[0].drawSelfAtPoint(showNextCanvas.context2D, new Point(0,0), this);
  }
  
  // Returns an empty two dimensional array
  // of bricks, all set to null
  List<List<Brick>> getEmptyBlocks(int w, int h) {
    List<List<Brick>> bl = new List<List<Brick>>();
      for(var i=0;i<h;i++) {
        bl.add(new List<Brick>.generate(w, (int index) => null ));
      }
    return bl;
  }
  
// set up key events
 void move(KeyboardEvent e) {
   switch(e.keyCode) {
     // left
     case 37:
       if(activeBlock.canMoveLeft(this)) {
         activeBlock.moveLeft();
       }
       break;
     // right
     case 39:
       if(activeBlock.canMoveRight(this)) {
         activeBlock.moveRight();
       }
       break;
     // up
     case 38:
       if(activeBlock.canRotate(this)) {
         activeBlock.rotate();
       }
       break;
     // down
     case 40:
       if(activeBlock.canMoveDown(this)) {
         activeBlock.moveDown();
       }
       break;
   }
 }
  
  // start the game
  void start() {
    gameOver = false;
    Rectangle rect = canvas.client;
    width = rect.width;
    height = rect.height;
    canvas.width = width;
    
    window.onKeyDown.listen(move);
    
    // determine size of each block, then determine
    // how many blocks high the wall can go
    brickWidth = width/numBricksX;
    numBricksY = (height~/brickWidth);
    
    bricks = getEmptyBlocks(numBricksX, numBricksY);
    
    addBlockToQueue(generateBlock());
    deployBlock(getNextBlock());
    
    window.requestAnimationFrame(draw);
  }
  
  void stop() {
    var context = canvas.context2D;
    context.fillStyle = "rgba(255,255,255,0.8)";
    context.fillRect(0, 0, width, height);
    gameOver = true;
  }
  
  // shifts everything downward
  void step() {
    // push active block down one
    if(activeBlock.canMoveDown(this)) {
      activeBlock.moveDown();
    } else {
      // stop and get a new active block
      // check if the game's over
      if(activeBlock.position.y < 0) {
        // TODO: notify loss
        stop();
        return;
      }
      writeBlockToBoard(activeBlock);
      // check for scoring
      runScoreCheck();
      
      deployBlock(getNextBlock());
    }
    
    turn++;
  }
  
  int getRowsScore(int rows) {
    int turnScore = turn~/10;
    switch(rows) {
      case 0:
        return 0;
      case 1:
        return 40 + (10*turnScore);
      case 2:
        return 100 + (10*turnScore);
      case 3:
        return 300 + (10*turnScore);
      case 4:
        return 1200 + (10*turnScore);
      default:
        return 500*rows + (10*turnScore);
    }
  }
  
  void addToScore(int s) {
    score += s;
    scoreBox.text = score.toString();
  }
  
  void runScoreCheck() {
    int rows = 0;
    for(var i=bricks.length-1;i>=0;i--) {
      bool rowClear = true;
      for(var j=0;j<bricks[i].length;j++) {
        if(bricks[i][j] == null) {
          rowClear = false;
          break;
        }
      }
      if(rowClear) {
        clearRow(i);
        rows++;
        i++;
      }
    }
    
    addToScore(getRowsScore(rows));
  }
  
  void clearRow(int row) {
    for(var i=row;i>=1;i--) {
      bricks[i] = bricks[i-1];
    }
    bricks[0] = new List<Brick>.generate(numBricksX, (index) => null);
  }
  
  void writeBlockToBoard(Block b) {
    for(int i=0;i<4;i++) {
      for(int j=0;j<4;j++) {
        Brick brick = b.bricks[i][j];
        if(brick == null) continue;
        var abs_x = b.position.x+j;
        var abs_y = b.position.y+i;
        
        if(abs_y < bricks.length && abs_x < bricks[i].length) {
          bricks[abs_y][abs_x] = brick;
        }
      }
    }
  }
  
  // Adds a block to the active block queue
  void addBlockToQueue(Block b) {
    int x = rng.nextInt(numBricksX-4);
    b.position = new Point(x, -4);
    blocksQueue.add(b);
  }
  
  Block getNextBlock() {
    addBlockToQueue(generateBlock());
    Block ret = blocksQueue.removeAt(0);
    showNext();
    return ret;
  }
  
  Block generateBlock() {
    String new_color = COLORS[currentColor%COLORS.length];
    currentColor++;
    
    int shapeIndex = rng.nextInt(SHAPES.length);
    List<List<int>> nums = SHAPES[shapeIndex];
    
    Block b = Block.getBlockFromInts(nums, new_color);
    // If we chose the long shape, set the shape
    // of the block to LONG
    if(shapeIndex == LONG_INDEX) {
      b.shape = Block.LONG;
    }
    
    int r = rng.nextInt(4);
    for(var i=0;i<r;i++) {
      b.rotate();
    }
    
    return b;
  }
  
  void deployBlock(Block b) {
    activeBlock = b;
  }
  
  void draw(num _) {
    var context = canvas.context2D;
    drawBackground(context);
    drawBricks(context);
    
    activeBlock.drawSelf(context, this);
    
    num time = new DateTime.now().millisecondsSinceEpoch;
    if(renderTime != null) {
      if(time - renderTime >= STEP_TIME) {
        step();
        renderTime = time;
      }
    } else {renderTime = time;}
    
    if(!gameOver) {
      window.requestAnimationFrame(draw);
    }
  }
  
  void drawBackground(CanvasRenderingContext2D context) {
    String c = BACKGROUND_COLOR;
    context.fillStyle = c;
    context.rect(0, 0, width, height);
    context.fill();
  }
  
  void drawBricks(CanvasRenderingContext2D context) {
    for(var i=0;i<numBricksY;i++) {
      for(var j=0;j<numBricksX;j++) {
        Brick b = bricks[i][j];
        if(b == null) continue;
        
        Point p = new Point(j, i);
        b.drawSelf(context, p, this);
      }
    }
  }
}

class Brick {
  String color;
  int value;
  bool active = false;
  Brick(this.value, this.color);
  
  void drawSelf(CanvasRenderingContext2D context, Point pos, Tetris t) {
    context.beginPath();
    Point p = t.getPointFromXY(pos.x, pos.y);
    context.rect(p.x + BLOCK_GAP, p.y + BLOCK_GAP,
                 t.brickWidth - BLOCK_GAP, t.brickWidth - BLOCK_GAP);
    context.fillStyle = color;
    context.fill();
  }
  
  String toString() {
    return color;
  }
}

class Block {
  static final num LEFT = 0;
  static final num RIGHT = 1;
  
  static final int LONG = 8;
  
  List<List<Brick>> bricks;
  String color;
  Point position;
  
  // hacky, indicate long shape for
  // rotation
  int shape;
  
  Block(this.bricks, this.color);
  
  static Block getBlockFromInts(List<List<int>> ints, var color) {
    List<List<Brick>> bricks = [[null,null,null,null],
                                [null,null,null,null],
                                [null,null,null,null],
                                [null,null,null,null]];;
    for(var i=0;i<4;i++) {
      for(var j=0;j<4;j++) {
        if(ints[i][j] == 0) continue;
        bricks[i][j] = new Brick(ints[i][j], color);
      }
    }
    
    Block b = new Block(bricks, color);
    
    return b;
  }
  
  bool canMoveDown(Tetris t) {
    for(var i=3;i>=0;i--) {
      // row directly under current row
      int index_under = position.y + i + 1;
      for(var j=3;j>=0;j--) {
        Brick block_brick = bricks[i][j];
        if(block_brick == null) continue;
        // if the block isn't null, then we can
        // only move down if there isn't a block
        // directly under
        if(index_under < 0) continue;
        if(!(index_under < t.numBricksY)) return false;
        if(t.bricks[index_under][position.x+j] != null) {
          return false;
        }
      }
    }
    return true;
  }
  
  bool canMoveLeft(Tetris t) {
    for(var i=0;i<4;i++) {
      int abs_y = position.y + i;
      for(var j=0;j<4;j++) {
        int index_left = position.x + j - 1;
        
        Brick block_brick = bricks[i][j];
        if(block_brick == null) continue;
        
        
        // if the block isn't null, then we can
        // only move to the left if there isn't
        // a block directly to the left
        if(index_left < 0) return false;
        if(abs_y < 0) continue;
        if(t.bricks[position.y+i][index_left] != null) {
          return false;
        }
      }
    }
    return true;
  }
  
  bool canMoveRight(Tetris t) {
    for(var i=0;i<4;i++) {
      int abs_y = position.y + i;
      for(var j=3;j>=0;j--) {
        int index_right = position.x + j + 1;
        
        Brick block_brick = bricks[i][j];
        if(block_brick == null) continue;
        
        // if the block isn't null, then we can
        // only move to the left if there isn't
        // a block directly to the left
        if(!(index_right < t.numBricksX)) return false;
        if(abs_y < 0) continue;
        if(t.bricks[position.y+i][index_right] != null) {
          return false;
        }
      }
    }
    return true;
  }
  
  bool canRotate(Tetris t) {
    List<List<Brick>> new_bricks = [[null,null,null,null],
                                    [null,null,null,null],
                                    [null,null,null,null],
                                    [null,null,null,null]];
    for(var i=0;i<4;i++) {
      for(var j=0;j<4;j++) {
        new_bricks[i][j] = bricks[i][j];
      }
    }
    
    Block new_block = new Block(new_bricks, color);
    new_block.position = position;
    new_block.rotate();
    for(var i=0;i<4;i++) {
      for(var j=0;j<4;j++) {
        Brick check = new_block.bricks[i][j];
        if(check == null) continue;
        
        int abs_y = new_block.position.y+i;
        int abs_x = new_block.position.x+j;
        if((abs_x < 0) || (abs_x >= t.numBricksX)) return false;
        if(abs_y >= t.numBricksY) return false;
        Brick exists = abs_y < 0 ? null : t.bricks[new_block.position.y+i][new_block.position.x+j];
        if(exists != null) {
          return false;
        }
      }
    }
    
    return true;
  }
  
  void drawSelf(CanvasRenderingContext2D context, Tetris t) {
    for(var i=0;i<bricks.length;i++) {
      for(var j=0;j<bricks[i].length;j++) {
        Brick brick = bricks[i][j];
        if(brick == null) continue;
        brick.drawSelf(context, new Point(position.x+j,  position.y+i), t);
      }
    }
  }
  
  void drawSelfAtPoint(CanvasRenderingContext2D context, Point p, Tetris t) {
    for(var i=0;i<bricks.length;i++) {
      for(var j=0;j<bricks[i].length;j++) {
        Brick brick = bricks[i][j];
        if(brick == null) continue;
        brick.drawSelf(context, new Point(p.x+j,  p.y+i), t);
      }
    }
  }
  
  void moveDown() {
    position = new Point(position.x, position.y+1);
  }
  
  void moveLeft() {
    position = new Point(position.x-1, position.y);
  }
  
  void moveRight() {
    position = new Point(position.x+1, position.y);
  }
  
  void rotate() {
    List<List<Brick>> new_bricks = [[null,null,null,null],
                                    [null,null,null,null],
                                    [null,null,null,null],
                                    [null,null,null,null]];
    // hack to rotate long bricks
    if(shape == LONG) {
      for(var i=0;i<4;i++) {
        for(var j=0;j<4;j++) {
          new_bricks[i][j] = bricks[j][i];
        }
      }
    } else {
      for(var i=0;i<3;i++) {
        for(var j=0;j<3;j++) {
          Brick brick = bricks[i][j];
          if(brick == null) continue;
          
          if(j == 0) {
            new_bricks[2][i] = brick;
          } else if (j == 1) {
            new_bricks[1][i] = brick;
          } else if(j == 2) {
            new_bricks[0][i] = brick;
          }
        }
      }
    }
    bricks = new_bricks;
  }
  
  String toString() {
    String ret = "";
    for(var i=0;i<4;i++) {
      ret += (bricks[i].toString() + "\n");
    }
    return ret;
  }
}