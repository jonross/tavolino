from tl.utils import *

class Column:

    """A Table, below, is made up of these (obviously)"""

    def __init__(self, data):
        # Array of column values
        self.data = data
        # User-addressible name like "c3" or "Sales"
        self.name = None
        # Column has an automatic name like "c3", not user-defined like "Sales"
        self.auto = True

    def clone(self):
        return Column(self.data[:])

class Table:

    """A set of Columns, above (obviously)"""

    def __init__(self, columns):
        self.columns = [self._wrap(c) for c in columns]
        # Column count
        self.width = None
        # Suppress final output (if a step has done custom output)
        self.suppress = False
        # Call this after every modification to .columns
        self.reset()

    def reset(self):
        self.width = len(self.columns)
        for index, column in enumerate(self.columns):
            if column.auto:
                column.name = "c%d" % (index + 1)

    def select(self, targets):
        result = [self.get_named(name) for name in targets.explicit]
        if targets.implicit:
            result += [self.columns[i] for i in range(targets.implicit - 1, self.width)]
        return result
        
    def get_named(self, name):
        index = self.index_of(name)
        if index is not None:
            return self.columns[index]
        die("No column named " + name)

    def index_of(self, thing):
        for index, column in enumerate(self.columns):
            if type(thing) == str and column.name == thing:
                return index
            if thing == column:
                return index
        return None

    def insert_after(self, column, new_column):
        self.columns.insert(1 + self.index_of(column), self._wrap(new_column))
        self.reset()

    def derive(self, targets, function, overwrite=False):
        """For each of the named columns, calculate a new column by applying the function to its
        values.  Optionally overwrite the existing column."""
        insert = self.replace_with if overwrite else self.insert_after
        for column in self.select(targets):
            insert(column, function(map(convert, column.data)))

    def replace_with(self, column, new_column):
        self.columns[self.index_of(column)] = self._wrap(new_column)
        self.reset()

    def _wrap(self, thing):
        return Column(thing) if type(thing) == list else thing

