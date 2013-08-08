package org.mirah.gallery

class Directory
  def self.init:void
    @@categories = DirectoryCategory[4]
    
    entries_0    = DirectoryEntry[3]
    entries_0[0] = DirectoryEntry.new('Red Balloon', R.drawable.red_balloon)
    entries_0[1] = DirectoryEntry.new('Green Balloon', R.drawable.green_balloon)
    entries_0[2] = DirectoryEntry.new('Blue Balloon', R.drawable.green_balloon)
    @@categories[0] = DirectoryCategory.new('Balloons', entries_0)
    
    entries_1    = DirectoryEntry[3]
    entries_1[0] = DirectoryEntry.new('Old school huffy', R.drawable.blue_bike)
    entries_1[1] = DirectoryEntry.new('New Bikes', R.drawable.rainbow_bike)
    entries_1[2] = DirectoryEntry.new('Chrome Fast', R.drawable.chrome_wheel)
    @@categories[1] = DirectoryCategory.new('Bikes', entries_1)
    
    entries_2    = DirectoryEntry[3]
    entries_2[0] = DirectoryEntry.new('Steampunk Android', R.drawable.punk_droid)
    entries_2[1] = DirectoryEntry.new('Stargazing Android', R.drawable.stargazer_droid)
    entries_2[2] = DirectoryEntry.new('Big Android', R.drawable.big_droid)
    @@categories[2] = DirectoryCategory.new('Androids', entries_2)
    
    entries_3    = DirectoryEntry[4]
    entries_3[0] = DirectoryEntry.new('Cupcake', R.drawable.cupcake)
    entries_3[1] = DirectoryEntry.new('Donut', R.drawable.donut)
    entries_3[2] = DirectoryEntry.new('Eclair', R.drawable.eclair)
    entries_3[3] = DirectoryEntry.new('Froyo', R.drawable.froyo)
    @categories[3] = DirectoryCategory.new('Pastries', entries_3)
  end
  
  def self.getCategoryCount:int
    @@categories.length
  end
  
  def self.getCategory(i:int):DirectoryCategory
    @@categories[i]
  end
end