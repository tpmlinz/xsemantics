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
package it.xsemantics.dsl.scoping;

import com.google.common.collect.Lists
import com.google.inject.Inject
import it.xsemantics.dsl.util.XsemanticsUtils
import it.xsemantics.dsl.xsemantics.Rule
import it.xsemantics.dsl.xsemantics.RuleInvocation
import it.xsemantics.dsl.xsemantics.RuleParameter
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.common.types.JvmOperation
import org.eclipse.xtext.xbase.XBlockExpression
import org.eclipse.xtext.xbase.XVariableDeclaration
import org.eclipse.xtext.xbase.annotations.scoping.XbaseWithAnnotationsScopeProvider
import org.eclipse.xtext.xbase.jvmmodel.IJvmModelAssociations
import org.eclipse.xtext.xbase.scoping.LocalVariableScopeContext
import org.eclipse.xtext.xbase.scoping.featurecalls.IValidatedEObjectDescription

import static org.eclipse.xtext.xbase.lib.IterableExtensions.*
import org.eclipse.xtext.xbase.scoping.XbaseScopeProvider.LocalVariableAcceptor

/**
 * This class contains custom scoping description. XbaseScopeProvider is
 * NOT used by the Xbase validator: it is used only by the content assist,
 * that's why it is still here, see
 * http://www.eclipse.org/forums/index.php/t/476486/
 * 
 * see : http://www.eclipse.org/Xtext/documentation/latest/xtext.html#scoping on
 * how and when to use it
 * 
 */
public class XsemanticsScopeProvider extends XbaseWithAnnotationsScopeProvider {
	@Inject
	protected XsemanticsUtils utils

	@Inject
	protected IJvmModelAssociations associations

	override protected void createLocalVarScope(LocalVariableAcceptor acceptor, LocalVariableScopeContext scopeContext) {
		val context = scopeContext.getContext();

		// The inferrer associates to a Rule both field(s) and methods
		// and we need the method (i.e., the JvmOperation) to actually
		// build a correct scope
		val jvmOperation = getJvmOperationAssociatedToSourceElement(context);

		if (jvmOperation == null) {
			super.createLocalVarScope(acceptor, scopeContext);
		} else {
			val declaredType = jvmOperation.getDeclaringType();
			createLocalVarScopeForJvmDeclaredType(declaredType, acceptor);
			createLocalVarScopeForJvmOperation(jvmOperation, acceptor);
		}

	}
	
	def private JvmOperation getJvmOperationAssociatedToSourceElement(
			EObject context) {
		val sourceElement = associations.getPrimarySourceElement(context);

		if (sourceElement == null)
			return null;

		val jvmElements = associations.getJvmElements(sourceElement);
		val jvmOperation = head(filter(jvmElements, JvmOperation));
		return jvmOperation;
	}

	override protected void createLocalVarScopeForBlock(XBlockExpression block, int indexOfContextExpressionInBlock,
			boolean referredFromClosure, LocalVariableAcceptor acceptor) {
		super.createLocalVarScopeForBlock(block,
				indexOfContextExpressionInBlock, referredFromClosure,
				acceptor);
		val descriptions = Lists.newArrayList();
		val container = block.eContainer();
		// add the output parameters as variable declarations
		if (container instanceof Rule) {
			val rule = container as Rule;
			addRuleParamsInDescriptions(utils.outputParams(rule), descriptions,
					referredFromClosure);
		}
		// add the variable declarations inside rule invocations
		for (expression : block.expressions.subList(0, indexOfContextExpressionInBlock)) {
			if (expression instanceof RuleInvocation) {
				val ruleInvocation = expression as RuleInvocation;
				val variableDeclarations = utils
						.getVariableDeclarations(ruleInvocation);
				for (varDecl : variableDeclarations) {
					addVariableDeclaration(descriptions, varDecl,
							referredFromClosure);
				}
			}
		}
		if (descriptions.isEmpty())
			return;
		acceptor.accept("XBlockExpression", descriptions);
	}

	def private void addRuleParamsInDescriptions(Iterable<RuleParameter> params,
			List<IValidatedEObjectDescription> descriptions,
			boolean referredFromClosure) {
		for (RuleParameter p : params) {
			if (p.getParameter().getName() != null) {
				val desc = createLocalVarDescription(p
						.getParameter());
				if (!referredFromClosure)
					descriptions.add(desc);
			}
		}
	}

	def protected void addVariableDeclaration(
			List<IValidatedEObjectDescription> descriptions,
			XVariableDeclaration varDecl, boolean referredFromClosure) {
		if (varDecl.getName() != null) {
			val desc = createLocalVarDescription(varDecl);
			if (!(referredFromClosure && varDecl.isWriteable()))
				descriptions.add(desc);
		}
	}
}
