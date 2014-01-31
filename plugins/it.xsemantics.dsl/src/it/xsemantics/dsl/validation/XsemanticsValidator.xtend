/*
 * generated by Xtext
 */
package it.xsemantics.dsl.validation

import com.google.inject.Inject
import it.xsemantics.dsl.typing.TupleType
import it.xsemantics.dsl.typing.XsemanticsTypeSystem
import it.xsemantics.dsl.util.XsemanticsMultimapsUtils
import it.xsemantics.dsl.util.XsemanticsNodeModelUtils
import it.xsemantics.dsl.util.XsemanticsUtils
import it.xsemantics.dsl.util.XsemanticsXExpressionHelper
import it.xsemantics.dsl.xsemantics.AuxiliaryDescription
import it.xsemantics.dsl.xsemantics.AuxiliaryFunction
import it.xsemantics.dsl.xsemantics.JudgmentDescription
import it.xsemantics.dsl.xsemantics.JudgmentParameter
import it.xsemantics.dsl.xsemantics.Rule
import it.xsemantics.dsl.xsemantics.RuleConclusionElement
import it.xsemantics.dsl.xsemantics.RuleInvocation
import it.xsemantics.dsl.xsemantics.RuleParameter
import it.xsemantics.dsl.xsemantics.XsemanticsPackage
import it.xsemantics.dsl.xsemantics.XsemanticsSystem
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.xtext.common.types.JvmFormalParameter
import org.eclipse.xtext.common.types.JvmTypeReference
import org.eclipse.xtext.common.types.TypesPackage
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.ValidationMessageAcceptor
import org.eclipse.xtext.xbase.XAssignment
import org.eclipse.xtext.xbase.XClosure
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.XFeatureCall
import org.eclipse.xtext.xbase.XReturnExpression
import org.eclipse.xtext.xbase.XThrowExpression
import org.eclipse.xtext.xbase.XbasePackage
import org.eclipse.xtext.xbase.lib.IterableExtensions

import static extension it.xsemantics.dsl.util.XsemanticsModelExtensions.*
import static extension org.eclipse.xtext.EcoreUtil2.*

//import org.eclipse.xtext.validation.Check

/**
 * Custom validation rules. 
 *
 * see http://www.eclipse.org/Xtext/documentation.html#validation
 */
class XsemanticsValidator extends AbstractXsemanticsValidator {

	@Inject
	protected XsemanticsTypeSystem typeSystem;

	@Inject
	protected extension XsemanticsUtils;

	@Inject
	protected XsemanticsXExpressionHelper xExpressionHelper;

	@Inject
	protected XsemanticsNodeModelUtils nodeModelUtils;

	public final static int maxOfOutputParams = 3;

	protected boolean enableWarnings = true;

	@Check
	override void checkAssignment(XAssignment assignment) {
		// we allow assignment to output parameters
		val assignmentFeature = assignment.getFeature();
		if (assignmentFeature instanceof JvmFormalParameter) {
			if (assignmentFeature.isInputParam()) {
				error("Assignment to input parameter",
						XbasePackage.Literals.XASSIGNMENT__ASSIGNABLE,
						ValidationMessageAcceptor.INSIGNIFICANT_INDEX,
						IssueCodes.ASSIGNMENT_TO_INPUT_PARAM);
			}
			return;
		}
		super.checkAssignment(assignment);
	}

	@Check
	override void checkReturn(XReturnExpression expr) {
		error("Return statements are not allowed here", expr, null,
				IssueCodes.RETURN_NOT_ALLOWED);
	}

//	@Override
//	protected boolean supportsCheckedExceptions() {
//		// we generate Java code which already handles exceptions
//		return false;
//	}

	def protected boolean isContainedInAuxiliaryFunction(XExpression expr) {
		return expr.getContainerOfType(AuxiliaryFunction) != null
	}

	override protected boolean isImplicitReturn(XExpression expr) {
		if (expr.isContainedInAuxiliaryFunction()) {
			return super.isImplicitReturn(expr);
		}

		// we will deal with this during generation
		return false;
	}

	@Check
	def void checkThrow(XThrowExpression expr) {
		error("Throw statements are not allowed here", expr, null,
				IssueCodes.THROW_NOT_ALLOWED);
	}

	override protected boolean isLocallyUsed(EObject target, EObject containerToFindUsage) {
		if (containerToFindUsage instanceof RuleInvocation) {
			// we don't want warning when a variable declaration appears as
			// output argument: it is implicitly used for the result
			return true;
		}
		return super.isLocallyUsed(target, containerToFindUsage);
	}

	override protected boolean isValueExpectedRecursive(XExpression expr) {
		// this is used by Xbase validator to check expressions with
		// side effects, by inspecting expr's container
		// so we must customize it when the container is one of our
		// custom XExpressions
		val valueExpectedRecursive = super
				.isValueExpectedRecursive(expr);
		return valueExpectedRecursive
				|| xExpressionHelper.isXsemanticsXExpression(expr.eContainer());
	}

	@Check
	def void checkJudgmentDescription(JudgmentDescription judgmentDescription) {
		checkNoDuplicateJudgmentDescriptionSymbols(judgmentDescription);
		checkNumOfOutputParams(judgmentDescription);
		checkInputParams(judgmentDescription);
		checkJudgmentDescriptionRules(judgmentDescription)
	}

	def void checkJudgmentDescriptionRules(
			JudgmentDescription judgmentDescription) {
		val rulesForJudgmentDescription = judgmentDescription.rulesForJudgmentDescription
		
		if (rulesForJudgmentDescription.isEmpty()) {
			if (isEnableWarnings && !judgmentDescription.override)
				warning("No rule defined for the judgment description",
					XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION
							.getEIDAttribute(),
					IssueCodes.NO_RULE_FOR_JUDGMENT_DESCRIPTION);
		} else {
			val judgmentParameters = judgmentDescription.judgmentParameters
			for (rule : rulesForJudgmentDescription) {
				val conclusionElements = rule.conclusion.conclusionElements
				// judgmentParameters.size() == conclusionElements.size())
				// otherwise we could not find a JudgmentDescription for the rule
				val judgmentParametersIt = judgmentParameters
						.iterator();
				for (RuleConclusionElement ruleConclusionElement : conclusionElements) {
					if (!judgmentParametersIt.next().isOutputParameter()
							&& !(ruleConclusionElement instanceof RuleParameter)) {
						error("Must be a parameter, not an expression",
								ruleConclusionElement,
								XsemanticsPackage.Literals.RULE_CONCLUSION_ELEMENT
										.getEIDAttribute(),
								IssueCodes.NOT_PARAMETER);
					}
				}
				
				rule.checkRuleConformantToJudgmentDescription(judgmentDescription)
			}
		}
	}

	def protected void checkNoDuplicateJudgmentDescriptionSymbols(
			JudgmentDescription judgmentDescription) {
		val judgmentSymbol = judgmentDescription.getJudgmentSymbol();
		val relationSymbols = judgmentDescription.getRelationSymbols();
		if (judgmentDescription.containingSystem().getJudgmentDescriptions(
				judgmentSymbol, relationSymbols).size() > 1) {
			error("Duplicate JudgmentDescription symbols: "
					+ symbolsRepresentation(judgmentSymbol, relationSymbols),
					XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION__JUDGMENT_SYMBOL,
					IssueCodes.DUPLICATE_JUDGMENT_DESCRIPTION_SYMBOLS);
		}
	}

	def protected void checkNumOfOutputParams(
			JudgmentDescription judgmentDescription) {
		if (judgmentDescription.outputJudgmentParameters()
				.size() > maxOfOutputParams) {
			error("No more than " + maxOfOutputParams
					+ " output parameters are handled at the moment",
					XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION__JUDGMENT_PARAMETERS,
					IssueCodes.TOO_MANY_OUTPUT_PARAMS);
		}
	}

	def protected void checkInputParams(JudgmentDescription judgmentDescription) {
		val inputParams = judgmentDescription.inputParams()
		if (inputParams.empty) {
			error("No input parameter; at least one is needed",
					XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION__JUDGMENT_PARAMETERS,
					IssueCodes.NO_INPUT_PARAM);
		} else {
			inputParams.checkDuplicateNames
		}
	}

	@Check
	def void checkRule(Rule rule) {
		val conclusion = rule.conclusion
		rule.findJudgmentDescriptionOrError(
			conclusion.judgmentSymbol, 
			conclusion.relationSymbols, 
			XsemanticsPackage.Literals.RULE__CONCLUSION);
	}

	@Check
	def public void checkRuleInvocation(RuleInvocation ruleInvocation) {
		val judgmentDescription = checkRuleInvocationConformantToJudgmentDescription(ruleInvocation);
		if (judgmentDescription != null) {
			val judgmentParameters = judgmentDescription
					.getJudgmentParameters();
			val invocationExpressions = ruleInvocation
					.getExpressions();
			// judgmentParamters.size() == conclusionElements.size())
			// otherwise we could not find a JudgmentDescription for the rule
			val judgmentParametersIt = judgmentParameters
					.iterator();
			for (XExpression ruleInvocationExpression : invocationExpressions) {
				if (judgmentParametersIt
						.next().isOutputParameter()) {
					if (!ruleInvocationExpression
							.validOutputArgExpression()) {
						error("Not a valid argument for output parameter: "
								+ nodeModelUtils
										.getProgramText(ruleInvocationExpression),
								ruleInvocationExpression,
								null,
								IssueCodes.NOT_VALID_OUTPUT_ARG);
					}
				} else {
					if (!ruleInvocationExpression
							.validInputArgExpression()) {
						error("Not a valid argument for input parameter: "
								+ nodeModelUtils
										.getProgramText(ruleInvocationExpression),
								ruleInvocationExpression,
								null,
								IssueCodes.NOT_VALID_INPUT_ARG);
					}
				}

			}
		}
	}

	@Check
	def public void checkSystem(XsemanticsSystem system) {
		val validatorExtends = system
				.getValidatorExtends();
		if (validatorExtends != null) {
			if (!typeSystem.isAbstractDeclarativeValidator(validatorExtends,
					system)) {
				error("Not an AbstractDeclarativeValidator: "
						+ getNameOfTypes(validatorExtends),
						XsemanticsPackage.Literals.XSEMANTICS_SYSTEM__VALIDATOR_EXTENDS,
						IssueCodes.NOT_VALIDATOR);
			}
		}
		val superSystem = system.getSuperSystem();
		if (superSystem != null) {
			if (!typeSystem.isValidSuperSystem(superSystem, system)) {
				error("Not an Xsemantics system: "
						+ getNameOfTypes(superSystem),
						XsemanticsPackage.Literals.XSEMANTICS_SYSTEM__SUPER_SYSTEM,
						IssueCodes.NOT_VALID_SUPER_SYSTEM);
			}
			if (validatorExtends != null) {
				error("system 'extends' cannot coexist with 'validatorExtends'",
						XsemanticsPackage.Literals.XSEMANTICS_SYSTEM__SUPER_SYSTEM,
						IssueCodes.EXTENDS_CANNOT_COEXIST_WITH_VALIDATOR_EXTENDS);
				error("system 'extends' cannot coexist with 'validatorExtends'",
						XsemanticsPackage.Literals.XSEMANTICS_SYSTEM__VALIDATOR_EXTENDS,
						IssueCodes.EXTENDS_CANNOT_COEXIST_WITH_VALIDATOR_EXTENDS);
			}
		}

		val superSystems = system
				.allSuperSystemDefinitions();
		if (superSystems.contains(system)) {
			error("Cycle in extends relation",
					XsemanticsPackage.Literals.XSEMANTICS_SYSTEM__SUPER_SYSTEM,
					IssueCodes.CYCLIC_HIERARCHY);
		}
		
		val superSystemDefinition = system.superSystemDefinition
		val allSuperJudgments = superSystemDefinition?.allJudgments
		system.judgmentDescriptions.
			checkOverrides(allSuperJudgments, [name], [override], 
			[j1, j2 |
				j1.judgmentSymbol == j2.judgmentSymbol &&
				j1.relationSymbols.elementsEqual(j2.relationSymbols) &&
				typeSystem.equals(j1, j2)
			],
			"judgment")

		val allSuperCheckRules = superSystemDefinition?.allCheckRules
		system.checkrules.
			checkOverrides(allSuperCheckRules, [name], [override], 
			[r1, r2 |
				typeSystem.equals(
							r1.element.parameter.parameterType, 
							r2.element.parameter.parameterType, 
							r1
						)
			],
			"checkrule")
		
		val allSuperRules = superSystemDefinition?.allRules
		system.rules.
			checkOverrides(allSuperRules, [name], [override], 
			[r1, r2 |
				r1.conclusion.judgmentSymbol.equals(r2.conclusion.judgmentSymbol) &&
				r1.conclusion.relationSymbols.elementsEqual(r2.conclusion.relationSymbols)
				&&
				typeSystem.equals(
					typeSystem.getInputTypes(r1),
					typeSystem.getInputTypes(r2), 
					r1
				)
			],
			"rule")
		
		for (rule : system.rules) {
			val conclusion = rule.conclusion
			val rulesOfTheSameKind = 
				system.allRulesByJudgmentDescription(
					conclusion.judgmentSymbol, conclusion.relationSymbols
				)
			if (rulesOfTheSameKind.size() > 1) {
				val tupleType = typeSystem.getInputTypes(rule);
				for (Rule rule2 : rulesOfTheSameKind) {
					if (rule2 != rule && !rule.isOverride()) {
						val tupleType2 = typeSystem.getInputTypes(rule2);
						if (typeSystem.equals(tupleType, tupleType2, rule)) {
							error("Duplicate rule of the same kind with parameters: "
									+ tupleTypeRepresentation(tupleType)
									+ reportContainingSystemName(rule2),
									rule,
									XsemanticsPackage.Literals.RULE__CONCLUSION,
									IssueCodes.DUPLICATE_RULE_WITH_SAME_ARGUMENTS);
						}
					}
				}
			}
		}
		
		val elements = system.injections + 
			system.judgmentDescriptions +
			system.auxiliaryDescriptions +
			// system.auxiliaryFunctions + 
			// aux functions have the same name of aux descriptions
			system.rules + 
			system.checkrules
		elements.checkDuplicateNames()
	}

	def private <T extends EObject> checkDuplicateNames(Iterable<T> collection) {
		if (!collection.empty) {
			val map = XsemanticsMultimapsUtils.duplicatesMultimap
			for (e : collection) {
				map.put(e.computeName, e)
			}

			for (entry : map.asMap.entrySet) {
				val duplicates = entry.value
				if (duplicates.size > 1) {
					for (d : duplicates)
						error(
							"Duplicate name '" + entry.key + "' (" + d.eClass.name + ")",
							d,
							null, 
							IssueCodes.DUPLICATE_NAME);
				}
			}
		}
	}

	def private <T extends EObject> checkOverrides(Iterable<T> collection, 
			Iterable<T> superCollection, 
			(T) => String nameComputer, 
			(T) => boolean overrideComputer,
			(T, T) => boolean conformanceComputer,
			String kind) {
		
		if (superCollection == null) {
			for (j : collection.filter[overrideComputer.apply(it)]) {
				error(
					"Cannot override " + kind + " without system 'extends'",
					j,
					null, 
					IssueCodes.OVERRIDE_WITHOUT_SYSTEM_EXTENDS);
			}
		} else {
			val superMap = superCollection.toMap[nameComputer.apply(it)]
			for (j : collection) {
				val name = nameComputer.apply(j)
				val overridden = superMap.get(name)
					
				if (!overrideComputer.apply(j)) {
					if (overridden != null)
						error(
							kind + " '" + name + "' must override " + kind +
								reportContainingSystemName(overridden),
							j,
							null, 
							IssueCodes.MUST_OVERRIDE);
				} else {
					if (overridden == null || !conformanceComputer.apply(j, overridden))
						error("No " + kind + " to override: " + name,
							j,
							null,
							IssueCodes.NOTHING_TO_OVERRIDE);
				}
			}
		}
	}

	@Check
	def public void checkAuxiliaryFunctions(AuxiliaryDescription aux) {
		val functionsForAuxiliaryDescrition = aux.functionsForAuxiliaryDescrition();
		if (isEnableWarnings
				&& functionsForAuxiliaryDescrition
						.isEmpty()) {
			warning("No function defined for the auxiliary description",
					XsemanticsPackage.Literals.AUXILIARY_DESCRIPTION
							.getEIDAttribute(),
					IssueCodes.NO_AUXFUN_FOR_AUX_DESCRIPTION);
		}
		
		if (functionsForAuxiliaryDescrition.size() > 1) {
			for (AuxiliaryFunction auxiliaryFunction : functionsForAuxiliaryDescrition) {
				val tupleType = typeSystem.getInputTypes(auxiliaryFunction);
				
				for (AuxiliaryFunction auxiliaryFunction2 : functionsForAuxiliaryDescrition) {
					val tupleType2 = typeSystem.getInputTypes(auxiliaryFunction2);
					if (auxiliaryFunction !== auxiliaryFunction2 && typeSystem.equals(tupleType, tupleType2, auxiliaryFunction)) {
						error("Duplicate auxiliary function of the same kind with parameters: "
								+ tupleTypeRepresentation(tupleType)
								+ reportContainingSystemName(auxiliaryFunction2),
								auxiliaryFunction2,
								XsemanticsPackage.Literals.AUXILIARY_FUNCTION__PARAMETERS,
								IssueCodes.DUPLICATE_AUXFUN_WITH_SAME_ARGUMENTS);
					}
				}
			}
		}
	}

	@Check
	def public void checkAuxiliaryFunctionHasAuxiliaryDescription(
			AuxiliaryFunction aux) {
		val auxiliaryDescription = aux
				.auxiliaryDescription();
		if (auxiliaryDescription == null) {
			error("No auxiliary description for auxiliary function '"
					+ aux.getName() + "'",
					XsemanticsPackage.Literals.AUXILIARY_FUNCTION__NAME,
					IssueCodes.NO_AUXDESC_FOR_AUX_FUNCTION);
		} else
			checkConformanceOfAuxiliaryFunction(aux, auxiliaryDescription);
	}

	@Check
	def public void checkOutputParamAccessWithinClosure(XFeatureCall featureCall) {
		val feature = featureCall.getFeature();
		if (feature instanceof JvmFormalParameter) {
			val container = feature.eContainer();
			if (container instanceof RuleParameter) {
				if ((container as RuleParameter).isOutputParam
						&& insideClosure(featureCall)) {
					error("Cannot refer to an output parameter "
							+ feature.getIdentifier()
							+ " from within a closure", featureCall, null,
							IssueCodes.ACCESS_TO_OUTPUT_PARAM_WITHIN_CLOSURE);
				}
			}
			return;
		}
	}

	def private boolean insideClosure(XFeatureCall featureCall) {
		return featureCall.getContainerOfType(XClosure) != null;
	}

	def protected void checkConformanceOfAuxiliaryFunction(AuxiliaryFunction aux,
			AuxiliaryDescription auxiliaryDescription) {
		val funParams = aux.getParameters();
		val descParams = auxiliaryDescription
				.getParameters();

		if (funParams.size() != descParams.size()) {
			error("expected " + descParams.size() + " parameter(s), but was "
					+ funParams.size(),
					aux,
					XsemanticsPackage.Literals.AUXILIARY_FUNCTION__PARAMETERS,
					IssueCodes.PARAMS_SIZE_DONT_MATCH);
		} else {
			val funParamsIt = funParams.iterator();
			for (JvmFormalParameter jvmFormalParameter : descParams) {
				val expected = typeSystem
						.getType(jvmFormalParameter);
				val funParam = funParamsIt.next();
				val actual = typeSystem.getType(funParam);
				if (!typeSystem.isConformant(expected, actual, funParam)) {
					error("parameter type "
							+ getNameOfTypes(actual)
							+ " is not subtype of AuxiliaryDescription declared type "
							+ getNameOfTypes(expected),
							funParam,
							TypesPackage.Literals.JVM_FORMAL_PARAMETER__PARAMETER_TYPE,
							IssueCodes.NOT_SUBTYPE);
				}
			}
		}
	}

	def protected String reportContainingSystemName(EObject object) {
		return ", in system: "
				+ object.containingSystem().getName();
	}

	def private void checkRuleConformantToJudgmentDescription(
			Rule rule,
			JudgmentDescription judgmentDescription) {
		val conclusion = rule.getConclusion();
		checkConformanceAgainstJudgmentDescription(
				judgmentDescription,
				conclusion,
				conclusion.getJudgmentSymbol(),
				conclusion.getRelationSymbols(),
				conclusion.getConclusionElements(), "Rule conclusion",
				XsemanticsPackage.Literals.RULE__CONCLUSION,
				XsemanticsPackage.Literals.RULE_CONCLUSION_ELEMENT
						.getEIDAttribute());
	}

	def private JudgmentDescription checkRuleInvocationConformantToJudgmentDescription(
			RuleInvocation ruleInvocation) {
		return checkConformanceAgainstJudgmentDescription(
				ruleInvocation,
				ruleInvocation.getJudgmentSymbol(),
				ruleInvocation.getRelationSymbols(),
				ruleInvocation.getExpressions(),
				"Rule invocation",
				XsemanticsPackage.Literals.RULE_INVOCATION.getEIDAttribute(),
				null);
	}

	def private JudgmentDescription checkConformanceAgainstJudgmentDescription(
			EObject element, String judgmentSymbol,
			Iterable<String> relationSymbols,
			Iterable<? extends EObject> elements,
			String elementDescription, EStructuralFeature elementFeature,
			EStructuralFeature conformanceFeature) {
		val judgmentDescription = element
				.findJudgmentDescriptionOrError(judgmentSymbol, relationSymbols, elementFeature);
		checkConformanceAgainstJudgmentDescription(
			judgmentDescription,
			element,
			judgmentSymbol,
			relationSymbols,
			elements,
			elementDescription,
			elementFeature,
			conformanceFeature
		)
		return judgmentDescription;
	}

	def private findJudgmentDescriptionOrError(EObject element, String judgmentSymbol,
			Iterable<String> relationSymbols, EStructuralFeature elementFeature) {
		val judgmentDescription = element
				.judgmentDescription(judgmentSymbol, relationSymbols);
		if (judgmentDescription == null) {
			error("No Judgment description for: "
					+ symbolsRepresentation(judgmentSymbol, relationSymbols),
					elementFeature, IssueCodes.NO_JUDGMENT_DESCRIPTION);
		}
		return judgmentDescription;
	}

	def private checkConformanceAgainstJudgmentDescription(
			JudgmentDescription judgmentDescription,
			EObject element, String judgmentSymbol,
			Iterable<String> relationSymbols,
			Iterable<? extends EObject> elements,
			String elementDescription, EStructuralFeature elementFeature,
			EStructuralFeature conformanceFeature) {
		if (judgmentDescription != null) {
			val judgmentParameters = judgmentDescription
					.getJudgmentParameters();
			val elementsIt = elements.iterator();
			for (judgmentParameter : judgmentParameters) {
				// the element might still be incomplete, thus we must check
				// whether there is an element to check against.
				// Recall that the judgment has been searched for using only
				// the symbols, not the rule conclusion elements
				if (elementsIt.hasNext())
					checkConformance(judgmentParameter, elementsIt.next(),
						elementDescription, conformanceFeature);
			}
		}
	}

	def protected void checkConformance(JudgmentParameter judgmentParameter,
			EObject element, String elementDescription,
			EStructuralFeature feature) {
		val expected = typeSystem.getType(judgmentParameter);
		val actual = typeSystem.getType(element);
		if (!typeSystem.isConformant(expected, actual, element)) {
			error(elementDescription + " type " + getNameOfTypes(actual)
					+ " is not subtype of JudgmentDescription declared type "
					+ getNameOfTypes(expected), element, feature,
					IssueCodes.NOT_SUBTYPE);
		}
	}

	def protected String symbolsRepresentation(String judgmentSymbol,
			Iterable<String> relationSymbols) {
		return judgmentSymbol + " "
				+ IterableExtensions.join(relationSymbols, " ");
	}

	def protected String tupleTypeRepresentation(TupleType tupleType) {
		val builder = new StringBuilder();
		val it = tupleType.iterator();
		while (it.hasNext()) {
			builder.append(getNameOfTypes(it.next()));
			if (it.hasNext())
				builder.append(", ");
		}
		return builder.toString();
	}

	def private Object getNameOfTypes(JvmTypeReference typeRef) {
		return if (typeRef == null)  "<null>" else typeRef.getSimpleName();
	}

	def public boolean isEnableWarnings() {
		return enableWarnings;
	}

	def public void setEnableWarnings(boolean enableWarnings) {
		this.enableWarnings = enableWarnings;
	}
	
}
