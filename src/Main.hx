package ;

#if flash
import flash.Lib;
#else
import neko.Lib;
#end
/**
 * ...
 * @author Scott Lee
 */

class Main 
{
	
	static function main() 
	{
		
		
		var bin:MaxRectsBinPack = new MaxRectsBinPack();
		bin.init(256, 256);
		
		var arr = [30, 20, 50, 20, 10, 80, 90, 20];
		
		for (i in 0...Std.int(arr.length / 2) ) 
		{
			var packedRect = bin.insert(arr[i * 2], arr[i * 2 + 1], RectBestShortSideFit);
			//Lib.println("Packed to (x,y)=(" + packedRect.x + "," + packedRect.y + "), (w,h)=(" + packedRect.width + "," + packedRect.height +"). Free space left: " + (100 - bin.occupancy()*100) + "%");
		}
		
		Lib.print(bin.usedRectangles);
	}
	
}