package org.mirah.gallery

import android.app.ActionBar
import android.app.ActionBar.Tab as ActionBarTab
import android.app.ActionBar.TabListener as ActionBarTabListener
import android.app.Activity
import android.view.ViewTreeObserver.OnGlobalLayoutListener as ViewTreeObserverOnGlobalLayoutListener
import android.app.FragmentTransaction
import android.app.ListFragment
import android.content.ClipData
import android.content.res.TypedArray
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.Drawable
import android.view.View
import android.view.View.DragShadowBuilder as ViewDragShadowBuilder
import android.view.ViewTreeObserver
import android.widget.AdapterView
import android.widget.AdapterView.OnItemLongClickListener as AdapterViewOnItemLongClickListener
import android.widget.ArrayAdapter
import android.widget.FrameLayout
import android.widget.FrameLayout.LayoutParams as FrameLayoutLayoutParams
import android.widget.ListView
import android.widget.AbsListView
import android.widget.TextView
import android.util.Log

import java.util.ArrayList

class Titles < ListFragment
  implements ActionBarTabListener
  
  def initialize
    @listener    = OnItemSelectedListener(nil)
    @category    = 0
    @curPosition = 0
    @dualFragments = false
    
    # Because the fragment doesn't have a reliable callback to notify us when
    # the activity's layout is completely drawn, this OnGlobalLayoutListener provides
    # the necessary callback so we can add top-margin to the ListView in order to dodge
    # the ActionBar. Which is necessary because the ActionBar is in overlay mode, meaning
    # that it will ordinarily sit on top of the activity layout as a top layer and
    # the ActionBar height can vary. Specifically, when on a small/normal size screen,
    # the action bar tabs appear in a second row, making the action bar twice as tall.
    # @layoutListener = lambda(ViewTreeObserverOnGlobalLayoutListener) do
    #   def onGlobalLayout:void
    #     barHeight = int(getActivity.getActionBar.getHeight)
    #     listView  = ListView(getListView)
    #     params    = FrameLayoutLayoutParams(listView.getLayoutParams)
    #     # The list view top-margin should always match the action bar height
    #     if (params.topMargin != barHeight)
    #       params.topMargin = barHeight
    #       listView.setLayoutParams(params)
    #     end
    #     # The action bar doesn't update its height when hidden, so make top-margin zero
    #     if !getActivity.getActionBar.isShowing
    #       params.topMargin = 0
    #       listView.setLayoutParams(params)
    #     end
    #   end
    # end
    #
    # ViewTreeObserver.OnGlobalLayoutListener layoutListener = new ViewTreeObserver.OnGlobalLayoutListener() {
    #     @Override
    #     public void onGlobalLayout() {
    #         int barHeight = getActivity().getActionBar().getHeight();
    #         ListView listView = getListView();
    #         FrameLayout.LayoutParams params = (LayoutParams) listView.getLayoutParams();
    #         // The list view top-margin should always match the action bar height
    #         if (params.topMargin != barHeight) {
    #             params.topMargin = barHeight;
    #             listView.setLayoutParams(params);
    #         }
    #         // The action bar doesn't update its height when hidden, so make top-margin zero
    #         if (!getActivity().getActionBar().isShowing()) {
    #           params.topMargin = 0;
    #           listView.setLayoutParams(params);
    #         }
    #     }
    # };
  end
  
  # Container Activity must implement this interface and we ensure
  # that it does during the onAttach() callback
  interface OnItemSelectedListener do
    def onItemSelected(category:int, position:int):void; end
  end
  
  def onAttach(activity:Activity):void
    super activity
    # fails if the container activity has not implemented the callback interface
    begin
      @listener = OnItemSelectedListener(activity)
    rescue ClassCastException => e
      Log.e getActivity.getLocalClassName, '#{activity} must implement OnItemSelectedListener'
    end
  end
  
  # This is where we perform setup for the fragment that's either
  # not related to the fragment's layout or must be done after the layout is drawn.
  # Notice that this fragment does not implement onCreateView(), because it extends
  # ListFragment, which includes a ListView as the root view by default, so there's
  # no need to set up the layout.
  def onActivityCreated(state):void
    super state
    
    frag = Body(getFragmentManager.findFragmentById R.id.content_frag)
    @dualFragments = true unless frag.nil?
    
    bar = ActionBar(getActivity.getActionBar)
    bar.setDisplayHomeAsUpEnabled(false)
    bar.setNavigationMode(ActionBar.NAVIGATION_MODE_TABS)
    
    # Must call in order to get callback to onCreateOptionsMenu()
    setHasOptionsMenu true
    
    Directory.init
    Directory.getCategoryCount.times do |i|
      bar.addTab(bar.newTab.setText(Directory.getCategory(i).getName)
              .setTabListener(self))
    end
    
    #Current position should survive screen rotations.
    unless state.nil?
      @category = state.getInt('category')
      @curPosition = state.getInt('listPosition')
      bar.selectTab(bar.getTabAt(@category))
    end

    populateTitles(@category)
    lv = ListView(getListView)
    lv.setCacheColorHint(Color.TRANSPARENT) # Improves scrolling performance

    if @dualFragments
      # Highlight the currently selected item
      lv.setChoiceMode(ListView.CHOICE_MODE_SINGLE)
      # Enable drag and dropping
      lv.setOnItemLongClickListener do |av, v, pos, id|
        title = String(TextView(v).getText)
        
        # Set up clip data with the category||entry_id format.
        textData = String.format('%d||%d', int(@category), pos)
        data = ClipData.newPlainText(title, textData)
        v.startDrag(data, MyDragShadowBuilder.new(v), nil, 0)
        return true
      end
      # lv.setOnItemLongClickListener(new OnItemLongClickListener() {
      #     public boolean onItemLongClick(AdapterView<?> av, View v, int pos, long id) {
      #         final String title = (String) ((TextView) v).getText()
      # 
      #         # Set up clip data with the category||entry_id format.
      #         final String textData = String.format('%d||%d', @category, pos)
      #         ClipData data = ClipData.newPlainText(title, textData)
      #         v.startDrag(data, new MyDragShadowBuilder(v), null, 0)
      #         return true
      #     }
      # })
    end

    # If showing both fragments, select the appropriate list item by default
    selectPosition(@curPosition) if @dualFragments

    # Attach a GlobalLayoutListener so that we get a callback when the layout
    # has finished drawing. This is necessary so that we can apply top-margin
    # to the ListView in order to dodge the ActionBar. Ordinarily, that's not
    # necessary, but we've set the ActionBar to 'overlay' mode using our theme,
    # so the layout does not account for the action bar position on its own.
    observer = ViewTreeObserver(getListView.getViewTreeObserver)
    this = self
    observer.addOnGlobalLayoutListener do
      def onGlobalLayout:void
        barHeight = int(this.getActivity.getActionBar.getHeight)
        listView  = ListView(this.getListView)
        params    = FrameLayoutLayoutParams(listView.getLayoutParams)
        # The list view top-margin should always match the action bar height
        if (params.topMargin != barHeight)
          params.topMargin = barHeight
          listView.setLayoutParams(params)
        end
        # The action bar doesn't update its height when hidden, so make top-margin zero
        if !this.getActivity.getActionBar.isShowing
          params.topMargin = 0
          listView.setLayoutParams(params)
        end
      end
    end
  end
  
  def onDestroyView:void
    super
    # Always detach ViewTreeObserver listeners when the view tears down
    this = self
    getListView.getViewTreeObserver.removeGlobalOnLayoutListener do
      def onGlobalLayout:void
        barHeight = int(this.getActivity.getActionBar.getHeight)
        listView  = ListView(this.getListView)
        params    = FrameLayoutLayoutParams(listView.getLayoutParams)
        # The list view top-margin should always match the action bar height
        if (params.topMargin != barHeight)
          params.topMargin = barHeight
          listView.setLayoutParams(params)
        end
        # The action bar doesn't update its height when hidden, so make top-margin zero
        if !this.getActivity.getActionBar.isShowing
          params.topMargin = 0
          listView.setLayoutParams(params)
        end
      end
    end
  end
  
  # Attaches an adapter to the fragment's ListView to populate it with items
  def populateTitles(category:int):void
    cat = DirectoryCategory(Directory.getCategory category)
    
    items   = ArrayList.new
    adapter = ArrayAdapter.new(getActivity, 
                                      R.layout.title_list_item, items)
    cat.getEntryCount.times do |i|
      adapter.add cat.getEntry(i).getName
    end
    
    # Convenience method to attach an adapter to ListFragment's ListView
    setListAdapter(adapter)
    
    @category = category
  end
  
  def onListItemClick(l:ListView, v:View, position:int, id:long):void
    # Send the event to the host activity via OnItemSelectedListener callback
    @listener.onItemSelected(@category, position)
    @curPosition = position
  end
  
  # Called to select an item from the listview
  def selectPosition(position:int):void
    # Only if we're showing both fragments should the item be 'highlighted'
    if @dualFragments
      lv = ListView(getListView)
      lv.setItemChecked(position, true)
    end
    # Calls the parent activity's implementation of the OnItemSelectedListener
    # so the activity can pass the event to the sibling fragment as appropriate
    @listener.onItemSelected(@category, position)
  end
  
  def onSaveInstanceState(outState):void
    super outState
    outState.putInt('listPosition', @curPosition)
    outState.putInt('category', @category)
  end
  
  # This defines how the draggable list items appear during a drag event
  class MyDragShadowBuilder < ViewDragShadowBuilder
    def initialize(v:View)
      super v
      a = TypedArray(v.getContext().obtainStyledAttributes(R.styleable.AppTheme))
      @shadow = Drawable(a.getDrawable R.styleable.AppTheme_listDragShadowBackground)
      @shadow.setCallback(v)
      @shadow.setBounds(0, 0, v.getWidth, v.getHeight)
      a.recycle
    end
    
    def onDrawShadow(canvas:Canvas):void
      super canvas
      @shadow.draw(canvas)
      getView.draw(canvas)
    end
  end
  
  # The following are callbacks implemented for the ActionBar.TabListener,
  # which this fragment implements to handle events when tabs are selected.
  #
  def onTabSelected(tab:ActionBarTab, ft:FragmentTransaction):void
    titleFrag = Titles(getFragmentManager
                                .findFragmentById(R.id.titles_frag))
    titleFrag.populateTitles(tab.getPosition)
    
    titleFrag.selectPosition(0) if @dualFragments
  end
  
  # These must be implemented, but we don't use them
  def onTabUnselected(tab:ActionBarTab, ft:FragmentTransaction):void; end
  def onTabReselected(tab:ActionBarTab, ft:FragmentTransaction):void; end
end

