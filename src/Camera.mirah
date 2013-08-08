package org.mirah.gallery

import android.app.Activity
import android.os.Bundle

class Camera < Activity
  def onCreate(state:Bundle):void
    setTheme(getIntent.getExtras.getInt 'theme')
    super state
    setContentView R.layout.camera_sample
  end
end

