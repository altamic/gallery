package org.mirah.gallery

import org.mirah.gallery.Titles.OnItemSelectedListener as TitlesOnItemSelectedListener
import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.animation.ValueAnimator.AnimatorUpdateListener
import android.app.ActionBar
import android.app.Activity
import android.app.AlertDialog
import android.app.AlertDialog.Builder as AlertDialogBuilder
import android.app.Dialog
import android.app.DialogFragment
import android.app.FragmentManager
import android.app.FragmentTransaction
import android.app.Notification
import android.app.Notification.Builder as NotificationBuilder
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.DialogInterface
import android.content.DialogInterface.OnClickListener as DialogInterfaceOnClickListener
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.view.Menu
import android.view.MenuInflater
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.view.ViewGroup.LayoutParams as ViewGroupLayoutParams
import android.widget.RemoteViews
import android.R as androidR

class Gallery < Activity
  implements TitlesOnItemSelectedListener
  
  def initialize
    @currentTitlesAnimator = Animator(nil)
    @toggleLabels = String[2]
    @toggleLabels[0] = 'Show Titles'
    @toggleLabels[1] = 'Hide Titles'
    
    @@NOTIFICATION_DEFAULT = 1
    @@ACTION_DIALOG = 'org.mirah.gallery.action.DIALOG'
    @themeId = -1
    @dualFragments = false
    @titlesHidden  = false
  end
  
  # see objectAnimator.addListener later
  attr_writer currentTitlesAnimator:Animator, titlesHidden:boolean 
  
  def onCreate(state:Bundle):void
    super state
    
    if not state.nil?
      if (state.getInt('theme', -1) != -1)
        @themeId = state.getInt 'theme'
        setTheme(@themeId)
      end
      @titlesHidden = state.getBoolean 'titlesHidden'
    end
      
    setContentView R.layout.main
    
    bar = getActionBar
    bar.setDisplayShowTitleEnabled(false)
    
    fm   = getFragmentManager
    frag = Body(fm.findFragmentById R.id.content_frag)
    @dualFragments = true unless frag.nil?
    
    titleFrag = Titles(fm.findFragmentById R.id.titles_frag)
    fm.beginTransaction.hide(titleFrag).commit if @titlesHidden
  end
  
  def onCreateOptionsMenu(menu:Menu):boolean
    inflater = getMenuInflater #MenuInflater
    inflater.inflate(R.menu.main_menu, menu);
    # If the device doesn't support camera, remove the camera menu item
    pkgMan   = getPackageManager
    camAvail = PackageManager.FEATURE_CAMERA
    menu.removeItem R.id.menu_camera if not pkgMan.hasSystemFeature(camAvail)
    true
  end
  
  def onPrepareOptionsMenu(menu:Menu):boolean
    # If not showing both fragments, remove the "toggle titles" menu item
    if not @dualFragments
      menu.removeItem R.id.menu_toggleTitles
    else
      menu.findItem(R.id.menu_toggleTitles).setTitle(@toggleLabels[@titlesHidden ? 0 : 1])
    end
    super menu
  end
  
  def onOptionsItemSelected(item)
      itemId = item.getItemId
      if itemId == R.id.menu_camera
        intent = Intent.new(self, Camera.class)
        intent.putExtra('theme', @themeId)
        startActivity intent
        return true
      elsif itemId == R.id.menu_toggleTitles
        toggleVisibleTitles
        return true
      elsif itemId == R.id.menu_toggleTheme
        @themeId = if (@themeId == R.style.AppTheme_Dark)
                     R.style.AppTheme_Light
                   else
                     R.style.AppTheme_Dark
                   end
        self.recreate
        return true
      elsif itemId == R.id.menu_showDialog
          showDialog 'This is indeed an awesome dialog.'
          return true
      elsif itemId ==  R.id.menu_showStandardNotification
          showNotification false
          return true
      elsif itemId ==  R.id.menu_showCustomNotification
          showNotification true
          return true
      else
        super item
      end
  end
  
  # Respond to the "toogle titles" item in the action bar
  def toggleVisibleTitles():void
    # Use these for custom animations.
    fm = FragmentManager(getFragmentManager)
    f  = Titles(fm.findFragmentById R.id.titles_frag)
    titlesView = View(f.getView)
    
    # Determine if we're in portrait, and whether we're showing or hiding the titles
    # with this toggle.
    portrait   = Configuration.ORIENTATION_PORTRAIT
    isPortrait = getResources.getConfiguration.orientation == portrait
    
    shouldShow = f.isHidden || !@currentTitlesAnimator.nil?
    
    # Cancel the current titles animation if there is one.
    @currentTitlesAnimator.cancel unless @currentTitlesAnimator.nil?
    
    # Begin setting up the object animator. We'll animate the bottom or right edge of the
    # titles view, as well as its alpha for a fade effect.
    bottomOrRight = isPortrait ? 'bottom' : 'right'
    sizeToShow    = shouldShow ? getResources.getDimensionPixelSize(R.dimen.titles_size) : 0
    objectAnimator = ObjectAnimator(ObjectAnimator.ofPropertyValuesHolder(
                                    titlesView,
                                    PropertyValuesHolder.ofInt(bottomOrRight, sizeToShow),
                                    PropertyValuesHolder.ofFloat('alpha', shouldShow ? 1 : 0)))
    
    # At each step of the animation, we'll perform layout by calling setLayoutParams.
    lp = ViewGroupLayoutParams(titlesView.getLayoutParams)
    
    objectAnimator.addUpdateListener do |valueAnimator|
      # *** WARNING ***: triggering layout at each animation frame highly impacts
      # performance so you should only do this for simple layouts. More complicated
      # layouts can be better served with individual animations on child views to
      # avoid the performance penalty of layout.
      if isPortrait
        lp.height = Integer(valueAnimator.getAnimatedValue)
      else
        lp.width  = Integer(valueAnimator.getAnimatedValue)
      end
      titlesView.setLayoutParams(lp)
    end
    # objectAnimator.addUpdateListener(new ValueAnimator.AnimatorUpdateListener() {
    #     public void onAnimationUpdate(ValueAnimator valueAnimator) {
    #         if (isPortrait) {
    #             lp.height = (Integer) valueAnimator.getAnimatedValue();
    #         } else {
    #             lp.width = (Integer) valueAnimator.getAnimatedValue();
    #         }
    #         titlesView.setLayoutParams(lp);
    #     }
    # });
    
    
    if shouldShow
      fm.beginTransaction.show(f).commit
      # https://groups.google.com/d/msg/mirah/NlUyIXVZnYc/j9gFAiA_IRQJ
      # You can use blocks for implementing an interface with multiple
      # methods.  Just put the method definition inside the block:
      # 
      #     foo.onBar do
      #        def onSuccess(result); end
      #        def onFailure(error); end
      #     end
      
      this = self # scoping
      objectAnimator.addListener lambda(AnimatorListenerAdapter) do
        def onAnimationEnd(animator:Animator):void
          this.currentTitlesAnimator = nil
          this.titlesHidden = false
          this.invalidateOptionsMenu
        end
      end
      # objectAnimator.addListener(new AnimatorListenerAdapter() {
      #     @Override
      #     public void onAnimationEnd(Animator animator) {
      #         mCurrentTitlesAnimator = null;
      #         mTitlesHidden = false;
      #         invalidateOptionsMenu();
      #     }
      # });
    else
      this = self # scoping
      objectAnimator.addListener lambda(AnimatorListenerAdapter) do
          def initialize
            @canceled = boolean(false)
          end
          
          def onAnimationCancel(animation:Animator):void
            @canceled = true
            super animation
          end
          
          def onAnimationEnd(animator:Animator):void
            return if @canceled
            
            this.currentTitlesAnimator = nil
            f = this.getFragmentManager.findFragmentById R.id.titles_frag
            this.getFragmentManager.beginTransaction.hide(f).commit
            this.titlesHidden = true
            this.invalidateOptionsMenu
          end
      end
      # objectAnimator.addListener(new AnimatorListenerAdapter() {
      #     boolean canceled;
      # 
      #     @Override
      #     public void onAnimationCancel(Animator animation) {
      #         canceled = true;
      #         super.onAnimationCancel(animation);
      #     }
      # 
      #     @Override
      #     public void onAnimationEnd(Animator animator) {
      #         if (canceled)
      #             return;
      #         mCurrentTitlesAnimator = null;
      #         fm.beginTransaction().hide(f).commit();
      #         mTitlesHidden = true;
      #         invalidateOptionsMenu();
      #     }
      # });
    end
    
    # Start the animation.
    objectAnimator.start
    @currentTitlesAnimator = objectAnimator
    
    # Manually trigger onNewIntent to check for ACTION_DIALOG.
    onNewIntent getIntent
  end
  
  def onNewIntent(intent:Intent):void
    extraText = intent.getStringExtra Intent.EXTRA_TEXT
    showDialog(extraText) if @@ACTION_DIALOG.equals(intent.getAction)
  end
  
  def showDialog(text:String):void
    # DialogFragment.show() will take care of adding the fragment
    # in a transaction.  We also want to remove any currently showing
    # dialog, so make our own transaction and take care of that here.
    ft = FragmentTransaction(getFragmentManager.beginTransaction)
    newFragment = DialogFragment(MyDialogFragment.newInstance(text))
    
    # Show the dialog.
    newFragment.show(ft, 'dialog')
  end
  
  def showNotification(custom:boolean):void
    res = getResources
    notifMgr = NotificationManager(getSystemService(getBaseContext.NOTIFICATION_SERVICE))
    
    builder = NotificationBuilder.new(self)
            .setSmallIcon(R.drawable.ic_stat_notify_example)
            .setAutoCancel(true)
            .setTicker(getString(R.string.notification_text))
            .setContentIntent(getDialogPendingIntent('Tapped the notification entry.'))
    
    if custom
      # Sets a custom content view for the notification, including an image button.
      layout = RemoteViews.new(getPackageName, R.layout.notification)
      layout.setTextViewText(R.id.notification_title, getString(R.string.app_name))
      layout.setOnClickPendingIntent(R.id.notification_button,
              getDialogPendingIntent("Tapped the 'dialog' button in the notification."))
      builder.setContent layout

      # Notifications in Android 3.0 now have a standard mechanism for displaying large
      # bitmaps such as contact avatars. Here, we load an example image and resize it to the
      # appropriate size for large bitmaps in notifications.
      largeIconTemp = Bitmap(BitmapFactory.decodeResource(res,
                                R.drawable.notification_default_largeicon))
      largeIcon = Bitmap(Bitmap.createScaledBitmap(
              largeIconTemp,
              res.getDimensionPixelSize(androidR.dimen.notification_large_icon_width),
              res.getDimensionPixelSize(androidR.dimen.notification_large_icon_height),
              false))
      largeIconTemp.recycle
    
      builder.setLargeIcon largeIcon
    else
      builder
        .setNumber(7) # An example number.
        .setContentTitle(getString R.string.app_name)
        .setContentText(getString R.string.notification_text)
    end
    
    notifMgr.notify(@@NOTIFICATION_DEFAULT, builder.getNotification)
  end
  
  def getDialogPendingIntent(dialogText:String):PendingIntent
    PendingIntent.getActivity(
            self,
            dialogText.hashCode(), # Otherwise previous PendingIntents with
                                   # the same requestCode may be overwritten.
            Intent.new(@@ACTION_DIALOG)
                    .putExtra(Intent.EXTRA_TEXT, dialogText)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            0)
  end
  
  def onSaveInstanceState(outState:Bundle):void
    super outState
    outState.putInt('theme', @themeId);
    outState.putBoolean('titlesHidden', @titlesHidden);
  end
  
  # Implementation for TitlesFragment.OnItemSelectedListener.
  # When the TitlesFragment receives an onclick event for a list item,
  # it's passed back to this activity through this method so that we can
  # deliver it to the ContentFragment in the manner appropriate
  def onItemSelected(category:int, position:int):void
    if not @dualFragments
      # If showing only the TitlesFragment, start the ContentActivity and
      # pass it the info about the selected item
      intent = Intent.new(self, Content.class)
      intent.putExtra('category', category)
      intent.putExtra('position', position)
      intent.putExtra('theme', @themeId)
      startActivity(intent);
    else
      # If showing both fragments, directly update the ContentFragment
      frag = Body(getFragmentManager.findFragmentById R.id.content_frag)
      frag.updateContentAndRecycleBitmap(category, position)
    end
  end
  
  class MyDialogFragment < DialogFragment
    def self.newInstance(title:String):MyDialogFragment
      frag = MyDialogFragment.new
      args = Bundle.new
      args.putString('text', title)
      frag.setArguments(args)
      frag
    end
    
    def onCreateDialog(state:Bundle):Dialog
      text = getArguments.getString 'text'
      
      AlertDialogBuilder.new(getActivity)
              .setTitle('A Dialog of Awesome')
              .setMessage(text)
              .setPositiveButton(androidR.string.ok) { |dialog, whichButton|
              }.create
    end
  end
end

