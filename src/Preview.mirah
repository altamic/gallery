package org.mirah.gallery

import android.hardware.Camera
import android.hardware.Camera.CameraInfo
import android.hardware.Camera.Size

import android.util.Log

import android.view.SurfaceHolder
import android.view.SurfaceHolder.Callback as SurfaceHolderCallback
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup

import java.io.IOException
import java.util.List

# A simple wrapper around a Camera and a SurfaceView that renders a centered
# preview of the Camera to the surface. We need to center the SurfaceView
# because not all devices have cameras that support preview sizes at the same
# aspect ratio as the device's display.

class Preview < ViewGroup
  implements SurfaceHolderCallback
  
  def initialize(context:Context)
    super context
    
    @TAG = 'Preview'
    
    @surfaceView = SurfaceView.new(context)
    self.addView(@surfaceView)
    
    # Install a SurfaceHolder.Callback so we get notified when the
    # underlying surface is created and destroyed.
    @holder = @surfaceView.getHolder
    @holder.addCallback(self)
    @holder.setType(SurfaceHolder.SURFACE_TYPE_PUSH_BUFFERS)
    
    @previewSize = Size(nil)
    
    @supportedPreviewSizes = List(nil)
    @camera = Camera(nil)
    @surfaceCreated = false
  end
  
  def setCamera(camera:Camera):void
    @camera = camera
    unless @camera.nil?
      @supportedPreviewSizes = @camera.getParameters.getSupportedPreviewSizes
      requestLayout if @surfaceCreated
    end
  end
  
  def switchCamera(camera:Camera):void
    setCamera(camera)
    begin
      camera.setPreviewDisplay(@holder)
    rescue IOException => e
      Log.e(@TAG, 'IOException caused by setPreviewDisplay()', e)
    end
  end
  
  def onMeasure(widthMeasureSpec:int, heightMeasureSpec:int):void
    # We purposely disregard child measurements because act as a
    # wrapper to a SurfaceView that centers the camera preview instead
    # of stretching it.
    width  = resolveSize(getSuggestedMinimumWidth, widthMeasureSpec)
    height = resolveSize(getSuggestedMinimumHeight, heightMeasureSpec)
    setMeasuredDimension(width, height)
    
    unless @supportedPreviewSizes.nil?
      @previewSize = getOptimalPreviewSize(@supportedPreviewSizes, width,
              height)
    end
    
    unless @camera.nil?
      parameters = @camera.getParameters # Camera.Parameters
      parameters.setPreviewSize(@previewSize.width, @previewSize.height)
      
      @camera.setParameters(parameters)
    end
  end
  
  def onLayout(changed:boolean, l:int, t:int, r:int, b:int):void
    if getChildCount > 0
      child = View(getChildAt 0)
      
      width = r - l;
      height = b - t;
      
      previewWidth = width;
      previewHeight = height;
      unless @previewSize.nil?
          previewWidth  = @previewSize.width
          previewHeight = @previewSize.height
      end
      
      # Center the child SurfaceView within the parent.
      if (width * previewHeight > height * previewWidth)
        scaledChildWidth = previewWidth * height / previewHeight
        child.layout((width - scaledChildWidth) / 2, 0,
                (width + scaledChildWidth) / 2, height)
      else
        scaledChildHeight = previewHeight * width / previewWidth
        child.layout(0, (height - scaledChildHeight) / 2, width,
                (height + scaledChildHeight) / 2)
      end
    end
  end
  
  def surfaceCreated(holder:SurfaceHolder):void
    # The Surface has been created, acquire the camera and tell it where
    # to draw.
    begin
      @camera.setPreviewDisplay(holder) unless @camera.nil?
    rescue IOException => e
      Log.e(@TAG, "IOException caused by setPreviewDisplay()", e)
    end
    
    requestLayout if @previewSize.nil?
    @surfaceCreated = true;
  end
  
  def  surfaceDestroyed(holder:SurfaceHolder):void
    # Surface will be destroyed when we return, so stop the preview.
    @camera.stopPreview unless @camera.nil?
  end
  
  def getOptimalPreviewSize(sizes:List, w:int, h:int):Size
    return Size(nil) if sizes.nil?
    
    optimalSize  = Size(nil)
    
    aspect_tolerance = double(0.1)
    targetRatio      = double(w / h)
    minDiff          = Double.MAX_VALUE
    targetHeight     = h
    
    sizes.each do |size|
      size = Size(size)
      ratio = double(size.width / size.height)
      next if (Math.abs(ratio - targetRatio) > aspect_tolerance)
      if Math.abs(size.height - targetHeight) < minDiff
        optimalSize = size;
        minDiff = Math.abs(size.height - targetHeight)
      end
    end
    
    if optimalSize.nil?
      minDiff = Double.MAX_VALUE
      sizes.each do |size|
        size = Size(size)
        if Math.abs(size.height - targetHeight) < minDiff
          optimalSize = size;
          minDiff = Math.abs(size.height - targetHeight)
        end
      end
    end
    
    optimalSize
  end
  
  def surfaceChanged(holder:SurfaceHolder, format:int, w:int, h:int):void
    # Now that the size is known, set up the camera parameters and begin
    # the preview.
    parameters = @camera.getParameters # Camera.Parameters
    parameters.setPreviewSize(@previewSize.width, @previewSize.height)
    requestLayout
    
    @camera.setParameters(parameters)
    @camera.startPreview
  end
end