Case of 
	: (FORM Event.code=On Selection Change)
		// Click, arrow keys, Page Up/Down and Home/End all land here. Selection is
		// local: no call, no process. The row is already a snapshot.
		If (Form.selectedPos>=1)
			Form.selectRow(Form.selectedPos; False)
		End if 
		
	: (FORM Event.code=On Double Clicked)
		// A double click asks the worker for a fresh get(id).
		Form.selectCurrent()
End case 
