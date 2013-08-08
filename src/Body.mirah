package org.mirah.gallery

import android.app.ActionBar
import android.app.Fragment
import android.content.ClipData
import android.content.ClipData.Item as ClipDataItem
import android.content.ClipDescription
import android.content.Intent
import android.graphics.Bitmap
import android.os.Parcelable
import android.graphics.Color
import android.net.Uri
import android.os.AsyncTask
import android.os.Bundle
import android.view.ActionMode
import android.view.ActionMode.Callback as ActionModeCallback
import android.view.DragEvent
import android.view.LayoutInflater
import android.view.Menu
import android.view.MenuInflater
import android.view.MenuItem
import android.view.View
import android.view.View.OnClickListener as ViewOnClickListener
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.view.WindowManager.LayoutParams as WindowManagerLayoutParams
import android.widget.ImageView
import android.widget.Toast
import android.R as androidR

import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.util.StringTokenizer

class Body < Fragment
  def initialize
    @contentView = View(nil)
    @category = 0
    @curPosition = 0
    @systemUiVisible = true
    @soloFragment = false

    # The bitmap currently used by ImageView
    @bitmap = Bitmap(nil)

    # Current action mode (contextual action bar, a.k.a. CAB)
    @currentActionMode = ActionMode(nil)
  end
  
  attr_reader contentView:View, systemUiVisible:boolean, soloFragment:boolean
  attr_accessor bitmap:Bitmap, currentActionMode:ActionMode
  
  # This is where we initialize the fragment's UI and attach some
  # event listeners to UI components.
  def onCreateView(inflater:LayoutInflater, container:ViewGroup, state:Bundle):View
    @contentView = inflater.inflate(R.layout.content_welcome, nil)
    @contentView.setDrawingCacheEnabled false
    
    # Handle drag events when a list item is dragged into the view
    imageView = ImageView(@contentView.findViewById R.id.image)
    this = self # scoping
    @contentView.setOnDragListener do |view, event|
      action = int(event.getAction)
      if action == DragEvent.ACTION_DRAG_ENTERED
        view.setBackgroundColor(
                this.getResources.getColor R.color.drag_active_color)
      elsif action == DragEvent.ACTION_DRAG_EXITED
        view.setBackgroundColor(Color.TRANSPARENT)
      elsif action == DragEvent.ACTION_DRAG_STARTED
        return this.processDragStarted(event)
      elsif action == DragEvent.ACTION_DROP
        view.setBackgroundColor(Color.TRANSPARENT)
        return this.processDrop(event, imageView)
      end
      false
    end
    
    # Show/hide the system status bar when single-clicking a photo.
    this = self # scoping
    @contentView.setOnClickListener do |view|
      # If we're in an action mode, don't toggle the action bar
      return if not this.currentActionMode.nil?
      
      if this.systemUiVisible
        this.setSystemUiVisible false
      else
        this.setSystemUiVisible true
      end
    end

    # When long-pressing a photo, activate the action mode for selection, showing the
    # contextual action bar (CAB).
    this = self # scoping
    @contentView.setOnLongClickListener do |view|
      return false if not this.currentActionMode.nil?
      
      this.currentActionMode = this.getActivity.startActionMode do
        def onCreateActionMode(actionMode:ActionMode, menu:Menu):boolean
          actionMode.setTitle(R.string.photo_selection_cab_title)
          
          menuInflater = MenuInflater(this.getActivity.getMenuInflater)
          menuInflater.inflate(R.menu.photo_context_menu, menu)
          true
        end
        
        def onPrepareActionMode(actionMode:ActionMode, menu:Menu):boolean
          false
        end
        
        def onActionItemClicked(actionMode:ActionMode, menuItem:MenuItem):boolean
          if R.id.menu_share == menuItem.getItemId
            this.shareCurrentPhoto
            actionMode.finish
            true
          else
            false
          end
        end
        
        def onDestroyActionMode(actionMode:ActionMode):void
          this.contentView.setSelected(false)
          this.currentActionMode = nil
        end
      end
      view.setSelected(true)
      true
    end
    
    @contentView
  end
  
  # This is where we perform additional setup for the fragment that's either
  # not related to the fragment's layout or must be done after the layout is drawn.
  # 
  def onActivityCreated(state:Bundle):void
    super state

    # Set member variable for whether this fragment is the only one in the activity
    listFragment = Fragment(getFragmentManager.findFragmentById R.id.titles_frag)
    @soloFragment = listFragment == nil ? true : false

    if @soloFragment
      # The fragment is alone, so enable up navigation
      getActivity.getActionBar.setDisplayHomeAsUpEnabled true
      # Must call in order to get callback to onOptionsItemSelected()
      setHasOptionsMenu true
    end

    # Current position and UI visibility should survive screen rotations.
    unless state.nil?
      setSystemUiVisible(state.getBoolean('systemUiVisible'))
      if @soloFragment
        # Restoring these members is not necessary when this fragment
        # is combined with the TitlesFragment, because when the TitlesFragment
        # is restored, it selects the appropriate item and sends the event
        # to the updateContentAndRecycleBitmap() method itself
        @category    = state.getInt 'category'
        @curPosition = state.getInt 'listPosition'
        updateContentAndRecycleBitmap(@category, @curPosition)
      end
    end

    if @soloFragment
      title = Directory.getCategory(@category).getEntry(@curPosition).getName
      bar   = getActivity.getActionBar # ActionBar
      bar.setTitle title
    end
  end
  
  def onOptionsItemSelected(item:MenuItem):boolean
    # This callback is used only when mSoloFragment == true (see onActivityCreated above)
    if item.getItemId == androidR.id.home
      # App icon in Action Bar clicked; go up
      intent = Intent.new(getActivity, Gallery.class)
      intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP) # Reuse the existing instance
      startActivity(intent)
      true
    else
      super item
    end
  end
  
  def onSaveInstanceState(outState:Bundle):void
    super outState
    outState.putInt('listPosition', @curPosition)
    outState.putInt('category', @category)
    outState.putBoolean('systemUiVisible', @systemUiVisible)
  end
  
  # Toggle whether the system UI (status bar / system bar) is visible.
  # This also toggles the action bar visibility.
  # @param show True to show the system UI, false to hide it.
  #
  def setSystemUiVisible(show:boolean):void
    @systemUiVisible = show

    window = getActivity.getWindow # Window
    winParams = window.getAttributes # WindowManager.LayoutParams 
    view = getView # View
    actionBar = getActivity.getActionBar # ActionBar
    
    if show
      # Show status bar (remove fullscreen flag)
      window.setFlags(0, WindowManagerLayoutParams.FLAG_FULLSCREEN)
      # Show system bar
      view.setSystemUiVisibility View.STATUS_BAR_VISIBLE
      # Show action bar
      actionBar.show
    else
      # Add fullscreen flag (hide status bar)
      window.setFlags(WindowManagerLayoutParams.FLAG_FULLSCREEN,
          WindowManagerLayoutParams.FLAG_FULLSCREEN)
      # Hide system bar
      view.setSystemUiVisibility View.STATUS_BAR_HIDDEN
      # Hide action bar
      actionBar.hide
    end
    window.setAttributes winParams
  end
  
  def processDragStarted(event:DragEvent):boolean
    # Determine whether to continue processing drag and drop based on the
    # plain text mime type.
    clipDesc = event.getClipDescription # ClipDescription
    mime = ClipDescription.MIMETYPE_TEXT_PLAIN
    return clipDesc.hasMimeType(mime) unless clipDesc.nil?
    false
  end
  
  def processDrop(event:DragEvent, imageView:ImageView):boolean
    # Attempt to parse clip data with expected format: category||entry_id.
    # Ignore event if data does not conform to this format.
    data = event.getClipData # ClipData
    unless data.nil?
      if data.getItemCount > 0
        item = ClipDataItem(data.getItemAt(0))
        textData = String(item.getText)
        unless textData.nil?
          tokenizer = StringTokenizer.new(textData, '||')
          return false if tokenizer.countTokens != 2
          
          category = -1
          entryId  = -1
          begin
            category = Integer.parseInt(tokenizer.nextToken)
            entryId = Integer.parseInt(tokenizer.nextToken)
          rescue NumberFormatException => exception
            return false
          end
          
          updateContentAndRecycleBitmap(category, entryId);
          # Update list fragment with selected entry.
          titlesFrag = TitlesFragment(getFragmentManager.findFragmentById R.id.titles_frag)
          titlesFrag.selectPosition entryId
          return true
        end
      end
    end
    return false
  end
  
  # Sets the current image visible.
  # @param category Index position of the image category
  # @param position Index position of the image
  # 
  def updateContentAndRecycleBitmap(category:int, position:int):void
    @category = category
    @curPosition = position
    
    @currentActionMode.finish unless @currentActionMode.nil?
    
    # This is an advanced call and should be used if you
    # are working with a lot of bitmaps. The bitmap is dead
    # after this call.
    @bitmap.recycle unless @bitmap.nil?
    
    # Get the bitmap that needs to be drawn and update the ImageView
    @bitmap = Directory.getCategory(category).getEntry(position)
            .getBitmap(getResources)
    (ImageView(getView.findViewById R.id.image)).setImageBitmap(@bitmap)
  end
  
  # Share the currently selected photo using an AsyncTask to compress the image
  # and then invoke the appropriate share intent.
  #
  def shareCurrentPhoto:void
    externalCacheDir = File(getActivity.getExternalCacheDir)
    if externalCacheDir.nil?
      Toast.makeText(getActivity(), 'Error writing to USB/external storage.',
              Toast.LENGTH_SHORT).show
      return
    end

    # Prevent media scanning of the cache directory.
    noMediaFile = File.new(externalCacheDir, '.nomedia')
    begin
      noMediaFile.createNewFile
    rescue IOException => e
    end
    
    # Write the bitmap to temporary storage in the external storage directory (e.g. SD card).
    # We perform the actual disk write operations on a separate thread using the
    # {@link AsyncTask} class, thus avoiding the possibility of stalling the main (UI) thread.
    
    tempFile = File.new(externalCacheDir, 'tempfile.jpg')
    this = self # scoping
    
    lambda(AsyncTask) do
      # 
      # Compress and write the bitmap to disk on a separate thread.
      # @return TRUE if the write was successful, FALSE otherwise.
      # 
      def doInBackground(params:Object[]):Object
        begin
          fo = FileOutputStream.new(tempFile, false)
          if not this.bitmap.compress(Bitmap.CompressFormat.JPEG, 60, fo)
            Toast.makeText(this.getActivity, 'Error writing bitmap data.',
                    Toast.LENGTH_SHORT).show
            Object(Boolean.FALSE)
          else
            Object(Boolean.TRUE)
          end
        rescue FileNotFoundException => e
          Toast.makeText(this.getActivity, 'Error writing to USB/external storage.',
                  Toast.LENGTH_SHORT).show
          Object(Boolean.FALSE)
        end
      end
      
      # 
      # After doInBackground completes (either successfully or in failure), we invoke an
      # intent to share the photo. This code is run on the main (UI) thread.
      # 
      def onPostExecute(result:Object):void
        return unless Boolean(result) == Boolean.TRUE
        shareIntent = Intent.new(Intent.ACTION_SEND)
        shareIntent.putExtra(Intent.EXTRA_STREAM, Uri.fromFile(tempFile))
        shareIntent.setType 'image/jpeg'
        startActivity Intent.createChooser(shareIntent, 'Share photo')
      end
    end.execute
  end
end
