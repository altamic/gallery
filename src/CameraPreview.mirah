package org.mirah.gallery

import android.app.ActionBar
import android.app.Activity
import android.app.Fragment
import android.content.Context
import android.content.Intent
import android.hardware.Camera
import android.hardware.Camera.CameraInfo as CameraCameraInfo
import android.hardware.Camera.Size as CameraSize
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.Menu
import android.view.MenuInflater
import android.view.MenuItem
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup

import android.R as androidR

import java.io.IOException
import java.util.List


class CameraPreview < Fragment
  def initialize
    @preview = Preview(nil)
    @camera  = Camera(nil)
    @numberOfCameras = 0
    @currentCamera   = 0        # Camera ID currently chosen
    @cameraCurrentlyLocked = 0  # Camera ID that's actually acquired
    @defaultCameraId = 0        # The first rear facing camera
  end
  
  def onCreate(state:Bundle):void
    super state
    
    # Create a container that will hold a SurfaceView for camera previews
    @preview = Preview.new(Context(getActivity))
    
    # Find the total number of cameras available
    @numberOfCameras = Camera.getNumberOfCameras
    
    # Find the ID of the rear-facing ("default") camera
    cameraInfo = CameraInfo.new
    
    @numberOfCameras.times do |i|
      Camera.getCameraInfo(i, cameraInfo)
      (@currentCamera = (@defaultCameraId = i)) if cameraInfo.facing == CameraInfo.CAMERA_FACING_BACK
    end
    
    setHasOptionsMenu(@numberOfCameras > 1)
  end
  
  def onActivityCreated(state:Bundle):void 
    super state
    # Add an up arrow to the "home" button, indicating that the button will go "up"
    # one activity in the app's Activity heirarchy.
    # Calls to getActionBar() aren't guaranteed to return the ActionBar when called
    # from within the Fragment's onCreate method, because the Window's decor hasn't been
    # initialized yet.  Either call for the ActionBar reference in Activity.onCreate()
    # (after the setContentView(...) call), or in the Fragment's onActivityCreated method.
    activity = self.getActivity # Activity
    actionBar = activity.getActionBar # ActionBar
    actionBar.setDisplayHomeAsUpEnabled true
  end
  
  def onCreateView(inflater:LayoutInflater,
                   container:ViewGroup,
                   savedInstanceState:Bundle):View
    @preview
  end
  
  def onResume():void
    super
    
    # Use @currentCamera to select the camera desired to safely restore
    # the fragment after the camera has been changed
    @camera = Camera.open(@currentCamera)
    @cameraCurrentlyLocked = @currentCamera
    @preview.setCamera(@camera)
  end
  
  def onPause():void
    super
    
    # Because the Camera object is a shared resource, it's very
    # important to release it when the activity is paused.
    unless @camera.nil?
      @preview.setCamera(nil)
      @camera.release
      @camera = nil
    end
  end
  
  def onCreateOptionsMenu(menu:Menu, inflater:MenuInflater):void
    if (@numberOfCameras > 1)
      # Inflate our menu which can gather user input for switching camera
      inflater.inflate(R.menu.camera_menu, menu)
    else
      super(menu, inflater)
    end
  end
  
  def onOptionsItemSelected(item:MenuItem):boolean
    # Handle item selection
    selection = item.getItemId
    if selection == R.id.menu_switch_cam
      # Release this camera -> @cameraCurrentlyLocked
      unless @camera.nil?
        @camera.stopPreview
        @preview.setCamera(nil)
        @camera.release
        @camera = nil
      end
      # Acquire the next camera and request Preview to reconfigure
      # parameters.
      @currentCamera = (@cameraCurrentlyLocked + 1) % @numberOfCameras
      @camera = Camera.open(@currentCamera)
      @cameraCurrentlyLocked = @currentCamera
      @preview.switchCamera(@camera)
      
      # Start the preview
      @camera.startPreview
      true
    elsif selection == androidR.id.home
      intent = Intent.new(getActivity, Gallery.class)
      intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP|Intent.FLAG_ACTIVITY_SINGLE_TOP)
      startActivity intent
      true
    else
      super item
    end
  end
end

