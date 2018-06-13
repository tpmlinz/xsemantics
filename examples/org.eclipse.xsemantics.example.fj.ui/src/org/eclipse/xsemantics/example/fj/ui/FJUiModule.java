/*******************************************************************************
 * Copyright (c) 2013-2017 Lorenzo Bettini.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   Lorenzo Bettini - Initial contribution and API
 *******************************************************************************/

/*
 * generated by Xtext
 */
package org.eclipse.xsemantics.example.fj.ui;

import org.eclipse.xsemantics.example.fj.ui.contentassist.FJProposalProvider;
import org.eclipse.xsemantics.example.fj.ui.labeling.FJLabelProvider;
import org.eclipse.xsemantics.example.fj.ui.wizard.FJProjectCreatorCustom;

import org.eclipse.ui.plugin.AbstractUIPlugin;

import org.eclipse.xtext.ui.editor.contentassist.IContentProposalProvider;
import org.eclipse.xtext.ui.wizard.IProjectCreator;

/**
 * Use this class to register components to be used within the IDE.
 */
public class FJUiModule extends org.eclipse.xsemantics.example.fj.ui.AbstractFJUiModule {

	public FJUiModule(AbstractUIPlugin plugin) {
		super(plugin);
	}

	@Override
	public Class<? extends IContentProposalProvider> bindIContentProposalProvider() {
		return FJProposalProvider.class;
	}

	@Override
	public java.lang.Class<? extends org.eclipse.jface.viewers.ILabelProvider> bindILabelProvider() {
		return FJLabelProvider.class;
	}

	@Override
	public Class<? extends IProjectCreator> bindIProjectCreator() {
		return FJProjectCreatorCustom.class;
	}

}