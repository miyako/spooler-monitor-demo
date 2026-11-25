If (FORM Event.code=On Clicked)
	// Selection is local: no call, no process. The row is already a snapshot.
	If (Form.selectedPos>=1)
		Form.selectRow(Form.selectedPos; False)
	End if 
End if 

If (FORM Event.code=On Double Clicked)
	// A double click asks the worker for a fresh get(id).
	Form.selectCurrent()
End if 
