package org.mirah.gallery

import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.Drawable

class DirectoryEntry
  def initialize(name:String, resID:int)
    @name  = name
    @resID = resID
  end
  
  def getName:String
    @name
  end
  
  def getDrawable(res:Resources):Drawable
    res.getDrawable(@resID)
  end
  
  def getBitmap(res:Resources):Bitmap
    BitmapFactory.decodeResource(res, @resID)
  end
end
