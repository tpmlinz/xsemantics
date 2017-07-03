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
package it.xsemantics.example.expressions;

import it.xsemantics.example.expressions.typing.ExpressionsSemantics;
import it.xsemantics.example.expressions.typing.ExpressionsStringRepresentation;
import it.xsemantics.example.expressions.typing.ExtendedExpressionsSemantics;
import it.xsemantics.runtime.StringRepresentation;

/**
 * Use this class to register components to be used at runtime / without the
 * Equinox extension registry.
 */
public class ExpressionsRuntimeModule extends
		it.xsemantics.example.expressions.AbstractExpressionsRuntimeModule {

	public Class<? extends StringRepresentation> bindStringRepresentation() {
		return ExpressionsStringRepresentation.class;
	}

	public Class<? extends ExpressionsSemantics> bindExpressionsSemantics() {
		return ExtendedExpressionsSemantics.class;
	}
}
