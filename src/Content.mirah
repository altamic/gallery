package org.mirah.gallery

import android.app.Activity

class Content < Activity
  def initialize
    @themeId = 0
  end
  
  def onCreate(state)
    super state
    extras = getIntent.getExtras
    
    if not extras.nil?
        # The activity theme is the only state data that the activity needs
        # to restore. All info about the content displayed is managed by the fragment
        @themeId = extras.getInt 'theme'
    elsif not state.nil? 
        # If there's no restore state, get the theme from the intent
        @themeId = state.getInt 'theme'
    end
    
    setTheme @themeId if not @themeId == 0
    setContentView R.layout.content_activity
    
    unless extras.nil?
      # Take the info from the intent and deliver it to the fragment so it can update
      category = extras.getInt 'category'
      position = extras.getInt 'position'
      frag = Body(getFragmentManager.findFragmentById R.id.content_frag)
      frag.updateContentAndRecycleBitmap(category, position);
    end
  end
  
  def onSaveInstanceState(outState):void
    super outState
    outState.putInt('theme', @themeId)
  end
end

