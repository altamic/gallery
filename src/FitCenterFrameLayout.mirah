package org.mirah.gallery

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup

# 
# A simple layout that fits and centers each child view, maintaining aspect ratio.
# 
class FitCenterFrameLayout < ViewGroup
  def initialize(context:Context)
    super context
  end
  
  def initialize(context:Context, attrs:AttributeSet)
    super(context, attrs)
  end
  
  def onMeasure(widthMeasureSpec:int, heightMeasureSpec:int):void
    # We purposely disregard child measurements.
    width = resolveSize(getSuggestedMinimumWidth, widthMeasureSpec)
    height = resolveSize(getSuggestedMinimumHeight, heightMeasureSpec)
    setMeasuredDimension(width, height)
    
    # MeasureSpec is a public static class of android.view.View
    childWidthSpec = MeasureSpec.makeMeasureSpec(width, MeasureSpec.UNSPECIFIED)
    childHeightSpec = MeasureSpec.makeMeasureSpec(height, MeasureSpec.UNSPECIFIED)

    childCount = getChildCount
    childCount.times do |i|
      getChildAt(i).measure(childWidthSpec, childHeightSpec)
    end
  end
  
  def onLayout(changed:boolean, l:int, t:int, r:int, b:int):void
    childCount = getChildCount
    
    parentLeft   = getPaddingLeft
    parentTop    = getPaddingTop
    parentRight  = r - l - getPaddingRight
    parentBottom = b - t - getPaddingBottom
    
    parentWidth = parentRight - parentLeft
    parentHeight = parentBottom - parentTop
    
    childCount.times do |i|
      child = View(getChildAt i)
      next if child.getVisibility == GONE
      
      # Fit and center the child within the parent. Make sure not to consider padding
      # as part of the child's aspect ratio.
      
      childPaddingLeft   = child.getPaddingLeft
      childPaddingTop    = child.getPaddingTop
      childPaddingRight  = child.getPaddingRight
      childPaddingBottom = child.getPaddingBottom
      
      unpaddedWidth  = child.getMeasuredWidth() - childPaddingLeft - childPaddingRight
      unpaddedHeight = child.getMeasuredHeight() - childPaddingTop - childPaddingBottom
      
      parentUnpaddedWidth = parentWidth - childPaddingLeft - childPaddingRight
      parentUnpaddedHeight = parentHeight - childPaddingTop - childPaddingBottom
      
      if (parentUnpaddedWidth * unpaddedHeight > parentUnpaddedHeight * unpaddedWidth)
        # The child view should be left/right letterboxed.
        scaledChildWidth = int(unpaddedWidth * parentUnpaddedHeight / unpaddedHeight + childPaddingLeft + childPaddingRight)
        child.layout(
                parentLeft + (parentWidth - scaledChildWidth) / 2,
                parentTop,
                parentRight - (parentWidth - scaledChildWidth) / 2,
                parentBottom)
      else
        # The child view should be top/bottom letterboxed.
        scaledChildHeight = int(unpaddedHeight * parentUnpaddedWidth / unpaddedWidth + childPaddingTop + childPaddingBottom)
        child.layout(
                parentLeft,
                parentTop + (parentHeight - scaledChildHeight) / 2,
                parentRight,
                parentTop + (parentHeight + scaledChildHeight) / 2)
      end
    end
  end
end

