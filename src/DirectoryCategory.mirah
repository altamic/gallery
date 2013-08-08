package org.mirah.gallery

class DirectoryCategory
  def initialize(name:String, entries:DirectoryEntry[])
    @name = name
    @entries = entries
  end
  
  def getName:String
    @name
  end
  
  def getEntryCount:int
    @entries.length
  end
  
  def getEntry(i:int):DirectoryEntry
    @entries[i]
  end
end

