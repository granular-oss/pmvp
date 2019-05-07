//
//  ItemEditPresenter.swift
//  GroceryListExample
//
//  Created by Aubrey Goodman on 4/17/19.
//  Copyright © 2019 Aubrey Goodman. All rights reserved.
//

import PMVP
import RxSwift

class ItemEditPresenter: Presenter<ItemEditViewState, ItemEditViewIntent> {

	private let valueText: UITextField

	private let cancelButton: UIBarButtonItem

	private let doneButton: UIBarButtonItem

	init(viewModel: ItemEditViewModel,
		 valueText: UITextField,
		 cancelButton: UIBarButtonItem,
		 doneButton: UIBarButtonItem) {
		self.valueText = valueText
		self.cancelButton = cancelButton
		self.doneButton = doneButton
		super.init(viewModel: viewModel)
	}

	override func registerObservers() {
		guard let viewModel = self.viewModel as? ItemEditViewModel else { return }
		viewModel.value()
			.do(onNext: { NSLog("item_edit_presenter.value(\($0))") })
			.bind(to: valueText.rx.text)
			.disposed(by: disposeBag)
		viewModel.canSave()
			.do(onNext: { NSLog("item_edit_presenter.can_save(\($0))") })
			.bind(to: doneButton.rx.isEnabled)
			.disposed(by: disposeBag)
	}
	
}
