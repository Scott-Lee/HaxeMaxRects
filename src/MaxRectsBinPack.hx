package ;

/**
 * ...
 * @author Scott Lee
 */
#if flash
typedef Rect = flash.geom.Rectangle;
#else
 typedef Rect = {
	var x:Int;
	var y:Int;
	var width:Int;
	var height:Int;
}
#end

enum FreeRectChoiceHeuristic
{
	RectBestShortSideFit; ///< -BSSF: Positions the rectangle against the short side of a free rectangle into which it fits the best.
	RectBestLongSideFit; ///< -BLSF: Positions the rectangle against the long side of a free rectangle into which it fits the best.
	RectBestAreaFit; ///< -BAF: Positions the rectangle into the smallest free rect into which it fits.
	RectBottomLeftRule; ///< -BL: Does the Tetris placement.
	RectContactPointRule; ///< -CP: Choosest the placement where the rectangle touches other rects as much as possible.
}
 
class MaxRectsBinPack
{
	inline public static var INT32_MAX =
	#if neko
	0x3fffffff;
	#else
	0x7fffffff;
	#end
	
	public var binWidth:Int;
	public var binHeight:Int;
	public var allowRotations:Bool;
	
	public var usedRectangles:Array<Rect>;
	public var freeRectangles:Array<Rect>;
	
	private var score1:Int; // Unused in this function. We don't need to know the score after finding the position.
	private var score2:Int;
	private var bestShortSideFit:Int;
	private var bestLongSideFit:Int;
	
	public function new() 
	{
		binWidth = 0;
		binHeight = 0;
		allowRotations = false;
		
		score1 = 0;
		score2 = 0;
		
		usedRectangles = new Array<Rect>();
		freeRectangles = new Array<Rect>();
	}
	/// (Re)initializes the packer to an empty bin of width x height units. Call whenever
	/// you need to restart with a new bin.
	public function init(width:Int, height:Int, rotations:Bool = true):Void
	{
		//if ( count(width) % 1 != 0 || count(height) % 1 != 0)
		if ( !count(width) || !count(height))
			return;
			//throw new Error("Must be 2,4,8,16,32,...512,1024,...");
		binWidth = width;
		binHeight = height;
		allowRotations = rotations;
		
		while (usedRectangles.length > 0)
			usedRectangles.pop();
		while (freeRectangles.length > 0)
			freeRectangles.pop();
		
		#if flash
		freeRectangles.push( new Rect(0, 0, width, height) );
		#else
		freeRectangles.push( { x:0, y:0, width:width, height:height } );
		#end
	}
	
	private function count(p:Int):Bool
	{
		while (p > 1)
		{
			if (p & 1 == 1) return false;
			else p >>= 1;
		}
		return true;
	}
	
	/**
	 * Insert a new Rectangle 
	 * @param width
	 * @param height
	 * @param method
	 * @return 
	 * 
	 */	
	public function insert(width:Int, height:Int,  method:FreeRectChoiceHeuristic):Rect {
		#if flash
		var newNode:Rect  = new Rect();
		#else
		var newNode:Rect  = { x:0, y:0, width:0, height:0 };
		#end
		score1 = 0;
		score2 = 0;
		switch(method) {
			case FreeRectChoiceHeuristic.RectBestShortSideFit:
				newNode = findPositionForNewNodeBestShortSideFit(width, height); 
			case FreeRectChoiceHeuristic.RectBottomLeftRule:
				newNode = findPositionForNewNodeBottomLeft(width, height, score1, score2); 
			case FreeRectChoiceHeuristic.RectContactPointRule:
				newNode = findPositionForNewNodeContactPoint(width, height, score1); 
			case FreeRectChoiceHeuristic.RectBestLongSideFit:
				newNode = findPositionForNewNodeBestLongSideFit(width, height, score2, score1); 
			case FreeRectChoiceHeuristic.RectBestAreaFit:
				newNode = findPositionForNewNodeBestAreaFit(width, height, score1, score2); 
		}
		
		if (newNode.height == 0)
			return newNode;
		
		var i:Int = 0;
		while (i < freeRectangles.length)
		{
			if (splitFreeNode(freeRectangles[i], newNode)) {
				freeRectangles.splice(i,1);
			} else
			{
				i++;
			}
		}
		
		pruneFreeList();
		usedRectangles.push(newNode);
		return newNode;
	}
	
	private function scoreRectangle( width:Int,  height:Int,  method:FreeRectChoiceHeuristic, 
									 score1:Int, score2:Int):Rect {
		#if flash
		var newNode:Rect  = new Rect();
		#else
		var newNode:Rect  = { x:0, y:0, width:0, height:0 };
		#end
		score1 = INT32_MAX;
		score2 = INT32_MAX;
		switch(method) {
			case FreeRectChoiceHeuristic.RectBestShortSideFit:
				newNode = findPositionForNewNodeBestShortSideFit(width, height); 
			case FreeRectChoiceHeuristic.RectBottomLeftRule:
				newNode = findPositionForNewNodeBottomLeft(width, height, score1,score2); 
			case FreeRectChoiceHeuristic.RectContactPointRule:
				newNode = findPositionForNewNodeContactPoint(width, height, score1); 
				// todo: reverse
				score1 = -score1; // Reverse since we are minimizing, but for contact point score bigger is better.
			case FreeRectChoiceHeuristic.RectBestLongSideFit:
				newNode = findPositionForNewNodeBestLongSideFit(width, height, score2, score1); 
			case FreeRectChoiceHeuristic.RectBestAreaFit:
				newNode = findPositionForNewNodeBestAreaFit(width, height, score1, score2); 
		}
		
		// Cannot fit the current Rectangle.
		if (newNode.height == 0) {
			score1 = INT32_MAX;
			score2 = INT32_MAX;
		}
		
		return newNode;
	}
	/// Computes the ratio of used surface area.
	public function occupancy():Float {
		var usedSurfaceArea:Float = 0;
		for (i in 0...usedRectangles.length)
			usedSurfaceArea += usedRectangles[i].width * usedRectangles[i].height;
		
		return usedSurfaceArea / (binWidth * binHeight);
	}
	
	private function findPositionForNewNodeBottomLeft(width:Int, height:Int, 
													  bestY:Int, bestX:Int) {
		#if flash
		var bestNode:Rect  = new Rect();
		#else
		var bestNode:Rect  = { x:0, y:0, width:0, height:0 };
		#end
		//memset(bestNode, 0, sizeof(Rectangle));
		
		bestY = INT32_MAX;
		var rect:Rect = null;
		var topSideY:Int;
		for (i in 0...freeRectangles.length)
		{
			rect = freeRectangles[i];
			// Try to place the Rectangle in upright (non-flipped) orientation.
			if (rect.width >= width && rect.height >= height) {
				topSideY = rect.y + height;
				if (topSideY < bestY || (topSideY == bestY && rect.x < bestX)) {
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = width;
					bestNode.height = height;
					bestY = topSideY;
					bestX = rect.x;
				}
			}
			//if (allowRotations && rect.width >= height && rect.height >= width) {
			if (rect.width >= height && rect.height >= width) {
				topSideY = rect.y + width;
				if (topSideY < bestY || (topSideY == bestY && rect.x < bestX)) {
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = height;
					bestNode.height = width;
					bestY = topSideY;
					bestX = rect.x;
				}
			}
		}
		return bestNode;
	}
	
	private function findPositionForNewNodeBestShortSideFit(width:Int, height:Int):Rect  {
		#if flash
		var bestNode:Rect  = new Rect();
		#else
		var bestNode:Rect  = { x:0, y:0, width:0, height:0 };
		#end
		//memset(&bestNode, 0, sizeof(Rectangle));
		
		bestShortSideFit = INT32_MAX;
		bestLongSideFit = score2;
		var rect:Rect;
		var leftoverHoriz:Int;
		var leftoverVert:Int;
		var shortSideFit:Int;
		var longSideFit:Int;
		//trace(width + "_" + height);
		for (i in 0...freeRectangles.length) {
			rect = freeRectangles[i];
			// Try to place the Rectangle in upright (non-flipped) orientation.
			if (rect.width >= width && rect.height >= height) {
				leftoverHoriz = abs(rect.width - width);
				leftoverVert = abs(rect.height - height);
				shortSideFit = min(leftoverHoriz, leftoverVert);
				longSideFit = max(leftoverHoriz, leftoverVert);
				
				if (shortSideFit < bestShortSideFit || (shortSideFit == bestShortSideFit && longSideFit < bestLongSideFit)) {
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = width;
					bestNode.height = height;
					bestShortSideFit = shortSideFit;
					bestLongSideFit = longSideFit;
				}
			}
			var flippedLeftoverHoriz:Int;
			var flippedLeftoverVert:Int;
			var flippedShortSideFit:Int;
			var flippedLongSideFit:Int;
			//if (allowRotations && rect.width >= height && rect.height >= width) {
			if (rect.width >= height && rect.height >= width) {
				var flippedLeftoverHoriz = abs(rect.width - height);
				var flippedLeftoverVert = abs(rect.height - width);
				var flippedShortSideFit = min(flippedLeftoverHoriz, flippedLeftoverVert);
				var flippedLongSideFit = max(flippedLeftoverHoriz, flippedLeftoverVert);
				
				if (flippedShortSideFit < bestShortSideFit || (flippedShortSideFit == bestShortSideFit && flippedLongSideFit < bestLongSideFit)) {
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = height;
					bestNode.height = width;
					bestShortSideFit = flippedShortSideFit;
					bestLongSideFit = flippedLongSideFit;
				}
			}
		}
		
		return bestNode;
	}
	
	private function  findPositionForNewNodeBestLongSideFit(width:Int, height:Int, bestShortSideFit:Int, bestLongSideFit:Int):Rect {
		#if flash
		var bestNode:Rect  = new Rect();
		#else
		var bestNode:Rect  = { x:0, y:0, width:0, height:0 };
		#end
		//memset(&bestNode, 0, sizeof(Rectangle));
		bestLongSideFit = INT32_MAX;
		var rect:Rect;
		
		var leftoverHoriz:Int;
		var leftoverVert:Int;
		var shortSideFit:Int;
		var longSideFit:Int;
		for (i in 0...freeRectangles.length) {
			rect = freeRectangles[i];
			// Try to place the Rectangle in upright (non-flipped) orientation.
			if (rect.width >= width && rect.height >= height) {
				leftoverHoriz = abs(rect.width - width);
				leftoverVert = abs(rect.height - height);
				shortSideFit = min(leftoverHoriz, leftoverVert);
				longSideFit = max(leftoverHoriz, leftoverVert);
				
				if (longSideFit < bestLongSideFit || (longSideFit == bestLongSideFit && shortSideFit < bestShortSideFit)) {
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = width;
					bestNode.height = height;
					bestShortSideFit = shortSideFit;
					bestLongSideFit = longSideFit;
				}
			}
			
			//if (allowRotations && rect.width >= height && rect.height >= width) {
			if (rect.width >= height && rect.height >= width) {
				leftoverHoriz = abs(rect.width - height);
				leftoverVert = abs(rect.height - width);
				shortSideFit = min(leftoverHoriz, leftoverVert);
				longSideFit = max(leftoverHoriz, leftoverVert);
				
				if (longSideFit < bestLongSideFit || (longSideFit == bestLongSideFit && shortSideFit < bestShortSideFit)) {
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = height;
					bestNode.height = width;
					bestShortSideFit = shortSideFit;
					bestLongSideFit = longSideFit;
				}
			}
		}
		trace(bestNode);
		return bestNode;
	}
	
	inline private function abs(p:Int):Int
	{
		return p > 0?p: -p;
	}
	
	inline private function min(p1:Int, p2:Int):Int
	{
		return p1 > p2? p2:p1;
	}
	
	inline private function max(p1:Int, p2:Int):Int
	{
		return p1 > p2?p1:p2;
	}
	
	private function findPositionForNewNodeBestAreaFit(width:Int, height:Int, bestAreaFit:Int, bestShortSideFit:Int):Rect {
		#if flash
		var bestNode:Rect  = new Rect();
		#else
		var bestNode:Rect  = { x:0, y:0, width:0, height:0 };
		#end
		//memset(&bestNode, 0, sizeof(Rectangle));
		
		bestAreaFit = INT32_MAX;
		
		var rect:Rect;
		
		var leftoverHoriz:Int;
		var leftoverVert:Int;
		var shortSideFit:Int;
		var areaFit:Int;
		
		for(i in 0...freeRectangles.length) {
			rect = freeRectangles[i];
			areaFit = rect.width * rect.height - width * height;
			
			// Try to place the Rectangle in upright (non-flipped) orientation.
			if (rect.width >= width && rect.height >= height) {
				leftoverHoriz = abs(rect.width - width);
				leftoverVert = abs(rect.height - height);
				shortSideFit = min(leftoverHoriz, leftoverVert);
				
				if (areaFit < bestAreaFit || (areaFit == bestAreaFit && shortSideFit < bestShortSideFit)) {
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = width;
					bestNode.height = height;
					bestShortSideFit = shortSideFit;
					bestAreaFit = areaFit;
				}
			}
			
			//if (allowRotations && rect.width >= height && rect.height >= width) {
			if (rect.width >= height && rect.height >= width) {
				leftoverHoriz = abs(rect.width - height);
				leftoverVert = abs(rect.height - width);
				shortSideFit = min(leftoverHoriz, leftoverVert);
				
				if (areaFit < bestAreaFit || (areaFit == bestAreaFit && shortSideFit < bestShortSideFit)) {
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = height;
					bestNode.height = width;
					bestShortSideFit = shortSideFit;
					bestAreaFit = areaFit;
				}
			}
		}
		return bestNode;
	}
	
	/// Returns 0 if the two intervals i1 and i2 are disjoint, or the length of their overlap otherwise.
	private function commonIntervalLength(i1start:Int, i1end:Int, i2start:Int, i2end:Int):Int {
		if (i1end < i2start || i2end < i1start)
			return 0;
		return min(i1end, i2end) - max(i1start, i2start);
	}
	
	private function contactPointScoreNode(x:Int, y:Int, width:Int, height:Int):Int {
		var score:Int = 0;
		
		if (x == 0 || x + width == binWidth)
			score += height;
		if (y == 0 || y + height == binHeight)
			score += width;
		var rect:Rect;
		//for (var i:int = 0; i < usedRectangles.length; i++) {
		for (i in 0...usedRectangles.length) {
			rect = usedRectangles[i];
			if (rect.x == x + width || rect.x + rect.width == x)
				score += commonIntervalLength(rect.y, rect.y + rect.height, y, y + height);
			if (rect.y == y + height || rect.y + rect.height == y)
				score += commonIntervalLength(rect.x, rect.x + rect.width, x, x + width);
		}
		return score;
	}
	
	private function findPositionForNewNodeContactPoint(width:Int, height:Int, bestContactScore:Int):Rect {
		#if flash
		var bestNode:Rect  = new Rect();
		#else
		var bestNode:Rect  = { x:0, y:0, width:0, height:0 };
		#end
		//memset(&bestNode, 0, sizeof(Rectangle));
		
		bestContactScore = -1;
		
		var rect:Rect;
		var score:Int;
		for (i in 0...freeRectangles.length) {
			rect = freeRectangles[i];
			// Try to place the Rectangle in upright (non-flipped) orientation.
			if (rect.width >= width && rect.height >= height) {
				score = contactPointScoreNode(rect.x, rect.y, width, height);
				if (score > bestContactScore) {
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = width;
					bestNode.height = height;
					bestContactScore = score;
				}
			}
			//if (allowRotations && rect.width >= height && rect.height >= width) {
			if (rect.width >= height && rect.height >= width) {
				score = contactPointScoreNode(rect.x, rect.y, height, width);
				if (score > bestContactScore) {
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = height;
					bestNode.height = width;
					bestContactScore = score;
				}
			}
		}
		return bestNode;
	}
	
	private function splitFreeNode(freeNode:Rect, usedNode:Rect):Bool {
		// Test with SAT if the Rectangles even intersect.
		if (usedNode.x >= freeNode.x + freeNode.width || usedNode.x + usedNode.width <= freeNode.x ||
			usedNode.y >= freeNode.y + freeNode.height || usedNode.y + usedNode.height <= freeNode.y)
			return false;
		//var newNode:Rect;
		if (usedNode.x < freeNode.x + freeNode.width && usedNode.x + usedNode.width > freeNode.x) {
			// New node at the top side of the used node.
			if (usedNode.y > freeNode.y && usedNode.y < freeNode.y + freeNode.height) {
				freeRectangles.push({ x:freeNode.x, y:freeNode.y, width:freeNode.width, height:usedNode.y - freeNode.y });
			}
			
			// New node at the bottom side of the used node.
			if (usedNode.y + usedNode.height < freeNode.y + freeNode.height) {
				//newNode = { x:freeNode.x, y:usedNode.y + usedNode.height, width:freeNode.width, height:freeNode.y + freeNode.height - (usedNode.y + usedNode.height) };
				freeRectangles.push({ x:freeNode.x, y:usedNode.y + usedNode.height, width:freeNode.width, height:freeNode.y + freeNode.height - (usedNode.y + usedNode.height) });
			}
		}
		
		if (usedNode.y < freeNode.y + freeNode.height && usedNode.y + usedNode.height > freeNode.y) {
			// New node at the left side of the used node.
			if (usedNode.x > freeNode.x && usedNode.x < freeNode.x + freeNode.width) {
				//newNode = { x:freeNode.x, y:freeNode.y, width:usedNode.x - newNode.x, height:freeNode.width };
				freeRectangles.push({ x:freeNode.x, y:freeNode.y, width:usedNode.x - freeNode.x, height:freeNode.width });
			}
			
			// New node at the right side of the used node.
			if (usedNode.x + usedNode.width < freeNode.x + freeNode.width) {
				freeRectangles.push({ x:usedNode.x + usedNode.width, y:freeNode.y, width:freeNode.x + freeNode.width - (usedNode.x + usedNode.width), height:freeNode.width });
			}
		}
		
		return true;
	}
	
	private function pruneFreeList():Void {
		var i:Int = 0;
		var j:Int = 0;
		//for (i in 0...freeRectangles.length)
		while (i < freeRectangles.length)
		{
			//for (j in (i+1)...freeRectangles.length) {
			j = i + 1;
			while (j < freeRectangles.length) {
				if (isContainedIn(freeRectangles[i], freeRectangles[j])) {
					freeRectangles.splice(i, 1);
					break;
				}
				if (isContainedIn(freeRectangles[j], freeRectangles[i])) {
					freeRectangles.splice(j,1);
				}
				j++;
			}
			i++;
		}
	}
	
	private function isContainedIn(a:Rect, b:Rect):Bool {
		return a.x >= b.x && a.y >= b.y 
			&& a.x+a.width <= b.x+b.width 
			&& a.y+a.height <= b.y+b.height;
	}
}