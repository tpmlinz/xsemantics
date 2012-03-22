package it.xsemantics.dsl.validation;

import it.xsemantics.dsl.typing.TupleType;
import it.xsemantics.dsl.typing.XsemanticsSubtyping;
import it.xsemantics.dsl.typing.XsemanticsTypingSystem;
import it.xsemantics.dsl.util.XsemanticsUtils;
import it.xsemantics.dsl.xsemantics.CheckRule;
import it.xsemantics.dsl.xsemantics.ErrorSpecification;
import it.xsemantics.dsl.xsemantics.JudgmentDescription;
import it.xsemantics.dsl.xsemantics.JudgmentParameter;
import it.xsemantics.dsl.xsemantics.Rule;
import it.xsemantics.dsl.xsemantics.RuleConclusion;
import it.xsemantics.dsl.xsemantics.RuleConclusionElement;
import it.xsemantics.dsl.xsemantics.RuleInvocation;
import it.xsemantics.dsl.xsemantics.RuleInvocationExpression;
import it.xsemantics.dsl.xsemantics.RuleParameter;
import it.xsemantics.dsl.xsemantics.XsemanticsPackage;

import java.util.Iterator;
import java.util.List;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.eclipse.xtext.EcoreUtil2;
import org.eclipse.xtext.common.types.JvmFormalParameter;
import org.eclipse.xtext.common.types.JvmIdentifiableElement;
import org.eclipse.xtext.common.types.JvmTypeReference;
import org.eclipse.xtext.validation.Check;
import org.eclipse.xtext.validation.ValidationMessageAcceptor;
import org.eclipse.xtext.xbase.XAssignment;
import org.eclipse.xtext.xbase.XClosure;
import org.eclipse.xtext.xbase.XExpression;
import org.eclipse.xtext.xbase.XReturnExpression;
import org.eclipse.xtext.xbase.XThrowExpression;
import org.eclipse.xtext.xbase.XbasePackage.Literals;
import org.eclipse.xtext.xbase.lib.IterableExtensions;

import com.google.inject.Inject;

@SuppressWarnings("restriction")
public class XsemanticsJavaValidator extends AbstractXsemanticsJavaValidator {

	@Inject
	protected XsemanticsTypingSystem typingSystem;

	@Inject
	protected XsemanticsSubtyping subtyping;

	@Inject
	protected XsemanticsUtils xsemanticsUtils;

	@Inject
	protected XsemanticsJavaValidatorHelper helper;

	public final static int maxOfOutputParams = 2;

	protected boolean enableWarnings = true;

	@Override
	@Check
	public void checkAssignment(XAssignment assignment) {
		// we allow assignment to output parameters
		JvmIdentifiableElement assignmentFeature = assignment.getFeature();
		if (assignmentFeature instanceof JvmFormalParameter) {
			if (xsemanticsUtils
					.isInputParam((JvmFormalParameter) assignmentFeature)) {
				error("Assignment to input parameter",
						Literals.XASSIGNMENT__ASSIGNABLE,
						ValidationMessageAcceptor.INSIGNIFICANT_INDEX,
						IssueCodes.ASSIGNMENT_TO_INPUT_PARAM);
			}
			return;
		}
		super.checkAssignment(assignment);
	}

	@Override
	@Check
	public void checkReturn(XReturnExpression expr) {
		error("Return statements are not allowed here", expr, null,
				IssueCodes.RETURN_NOT_ALLOWED);
	}

	@Check
	public void checkThrow(XThrowExpression expr) {
		error("Throw statements are not allowed here", expr, null,
				IssueCodes.THROW_NOT_ALLOWED);
	}

	@Override
	protected boolean isLocallyUsed(EObject target, EObject containerToFindUsage) {
		if (containerToFindUsage instanceof RuleInvocationExpression) {
			// we don't want warning when a variable declaration appears as
			// output argument: it is implicitly used for the result
			return true;
		}
		return super.isLocallyUsed(target, containerToFindUsage);
	}
	
	@Override
	protected void mustBeJavaStatementExpression(XExpression expr) {
		if (typingSystem.isBooleanPremise(expr)) {
			// in this case we consider it valid
			// since it will be generated correctly
			return;
		}
		super.mustBeJavaStatementExpression(expr);
	}

	@Check
	public void checkJudgmentDescription(JudgmentDescription judgmentDescription) {
		checkNoDuplicateJudgmentDescriptionSymbols(judgmentDescription);
		checkNumOfOutputParams(judgmentDescription);
		checkNumOfInputParams(judgmentDescription);
	}

	@Check
	public void checkJudgmentDescriptionHasRules(
			JudgmentDescription judgmentDescription) {
		if (enableWarnings
				&& xsemanticsUtils.rulesForJudgmentDescription(
						judgmentDescription).isEmpty()) {
			warning("No rule defined for the judgment description",
					XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION
							.getEIDAttribute(),
					IssueCodes.NO_RULE_FOR_JUDGMENT_DESCRIPTION);
		}
	}

	protected void checkNoDuplicateJudgmentDescriptionSymbols(
			JudgmentDescription judgmentDescription) {
		String judgmentSymbol = judgmentDescription.getJudgmentSymbol();
		List<String> relationSymbols = judgmentDescription.getRelationSymbols();
		if (xsemanticsUtils.getJudgmentDescriptions(
				xsemanticsUtils.containingTypeSystem(judgmentDescription),
				judgmentSymbol, relationSymbols).size() > 1) {
			error("Duplicate JudgmentDescription symbols: "
					+ symbolsRepresentation(judgmentSymbol, relationSymbols),
					XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION__JUDGMENT_SYMBOL,
					IssueCodes.DUPLICATE_JUDGMENT_DESCRIPTION_SYMBOLS);
		}
	}

	protected void checkNumOfOutputParams(
			JudgmentDescription judgmentDescription) {
		if (xsemanticsUtils.outputJudgmentParameters(judgmentDescription).size() > maxOfOutputParams) {
			error("No more than " + maxOfOutputParams
					+ " output parameters are handled at the moment",
					XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION__JUDGMENT_PARAMETERS,
					IssueCodes.TOO_MANY_OUTPUT_PARAMS);
		}
	}

	protected void checkNumOfInputParams(JudgmentDescription judgmentDescription) {
		if (xsemanticsUtils.inputParams(judgmentDescription).isEmpty()) {
			error("No input parameter; at least one is needed",
					XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION__JUDGMENT_PARAMETERS,
					IssueCodes.NO_INPUT_PARAM);
		}
	}

	@Check
	public void checkRule(Rule rule) {
		checkNoDuplicateRulesWithSameArguments(rule);
		JudgmentDescription judgmentDescription = checkRuleConformantToJudgmentDescription(rule);
		if (judgmentDescription != null) {
			List<JudgmentParameter> judgmentParameters = judgmentDescription
					.getJudgmentParameters();
			List<RuleConclusionElement> conclusionElements = rule
					.getConclusion().getConclusionElements();
			// judgmentParameters.size() == conclusionElements.size())
			// otherwise we could not find a JudgmentDescription for the rule
			Iterator<JudgmentParameter> judgmentParametersIt = judgmentParameters.iterator();
			for (RuleConclusionElement ruleConclusionElement : conclusionElements) {
				if (!xsemanticsUtils.isOutputParameter(judgmentParametersIt.next())
						&& !(ruleConclusionElement instanceof RuleParameter)) {
					error("Must be a parameter, not an expression",
							ruleConclusionElement,
							XsemanticsPackage.Literals.RULE_CONCLUSION_ELEMENT
									.getEIDAttribute(),
							IssueCodes.NOT_PARAMETER);
				}
			}
		}
	}

	@Check
	public void checkNoCheckRulesWithTheSameName(Rule rule) {
		if (!helper.noRulesWithTheSameName(rule)) {
			error("Duplicate checkrule with the same name", rule,
					XsemanticsPackage.Literals.RULE__NAME,
					IssueCodes.DUPLICATE_RULE_NAME);
		}
	}

	@Check
	public void checkNoRulesWithTheSameName(CheckRule rule) {
		if (!helper.noRulesWithTheSameName(rule)) {
			error("Duplicate rule with the same name", rule,
					XsemanticsPackage.Literals.CHECK_RULE__NAME,
					IssueCodes.DUPLICATE_RULE_NAME);
		}
	}

	@Check
	public void checkRuleInvocation(RuleInvocation ruleInvocation) {
		JudgmentDescription judgmentDescription = checkRuleInvocationConformantToJudgmentDescription(ruleInvocation);
		boolean insideClosure = isInsideClosure(ruleInvocation);
		if (judgmentDescription != null) {
			List<JudgmentParameter> judgmentParameters = judgmentDescription
					.getJudgmentParameters();
			List<RuleInvocationExpression> invocationExpressions = ruleInvocation
					.getExpressions();
			// judgmentParamters.size() == conclusionElements.size())
			// otherwise we could not find a JudgmentDescription for the rule
			Iterator<JudgmentParameter> judgmentParametersIt = judgmentParameters.iterator();
			for (RuleInvocationExpression ruleInvocationExpression : invocationExpressions) {
				if (xsemanticsUtils.isOutputParameter(judgmentParametersIt.next())) {
					if (!xsemanticsUtils
							.validOutputArgExpression(ruleInvocationExpression)) {
						error("Not a valid argument for output parameter",
								ruleInvocationExpression,
								XsemanticsPackage.Literals.RULE_INVOCATION_EXPRESSION__EXPRESSION,
								IssueCodes.NOT_VALID_OUTPUT_ARG);
					}
					if (insideClosure) {
						error("Cannot use output parameter inside closure",
								ruleInvocationExpression,
								XsemanticsPackage.Literals.RULE_INVOCATION_EXPRESSION__EXPRESSION,
								IssueCodes.NOT_VALID_OUTPUT_ARG_INSIDE_CLOSURE);
					}
				} else {
					if (!xsemanticsUtils
							.validInputArgExpression(ruleInvocationExpression)) {
						error("Not a valid argument for input parameter",
								ruleInvocationExpression,
								XsemanticsPackage.Literals.RULE_INVOCATION_EXPRESSION__EXPRESSION,
								IssueCodes.NOT_VALID_INPUT_ARG);
					}
				}

			}
		}
	}

	protected boolean isInsideClosure(RuleInvocation ruleInvocation) {
		return EcoreUtil2.getContainerOfType(ruleInvocation, XClosure.class) != null;
	}

	@Check
	public void checkErrorSpecification(ErrorSpecification errorSpecification) {
		XExpression source = errorSpecification.getSource();
		if (source != null) {
			JvmTypeReference sourceType = typingSystem.getType(source);
			if (!subtyping.isEObject(sourceType, errorSpecification)) {
				error("Not an EObject: " + getNameOfTypes(sourceType),
						XsemanticsPackage.Literals.ERROR_SPECIFICATION__SOURCE,
						IssueCodes.NOT_EOBJECT);
			}
		}
		XExpression feature = errorSpecification.getFeature();
		if (feature != null) {
			JvmTypeReference featureType = typingSystem.getType(feature);
			if (!subtyping
					.isEStructuralFeature(featureType, errorSpecification)) {
				error("Not an EStructuralFeature: "
						+ getNameOfTypes(featureType),
						XsemanticsPackage.Literals.ERROR_SPECIFICATION__FEATURE,
						IssueCodes.NOT_ESTRUCTURALFEATURE);
			}
		}
	}

	protected void checkNoDuplicateRulesWithSameArguments(Rule rule) {
		List<Rule> rulesOfTheSameKind = xsemanticsUtils
				.getRulesOfTheSameKind(rule);
		if (rulesOfTheSameKind.size() > 1) {
			TupleType tupleType = typingSystem.getInputTypes(rule);
			for (Rule rule2 : rulesOfTheSameKind) {
				if (rule2 != rule) {
					TupleType tupleType2 = typingSystem.getInputTypes(rule2);
					if (subtyping.equals(tupleType, tupleType2)) {
						error("Duplicate rule of the same kind with parameters: "
								+ tupleTypeRepresentation(tupleType),
								XsemanticsPackage.Literals.RULE__CONCLUSION,
								IssueCodes.DUPLICATE_RULE_WITH_SAME_ARGUMENTS);
						break;
					}
				}
			}
		}
	}

	protected JudgmentDescription checkRuleConformantToJudgmentDescription(
			Rule rule) {
		RuleConclusion conclusion = rule.getConclusion();
		return checkConformanceAgainstJudgmentDescription(conclusion,
				conclusion.getJudgmentSymbol(),
				conclusion.getRelationSymbols(),
				conclusion.getConclusionElements(), "Rule conclusion",
				XsemanticsPackage.Literals.RULE__CONCLUSION,
				XsemanticsPackage.Literals.RULE_CONCLUSION_ELEMENT
						.getEIDAttribute());
	}

	protected JudgmentDescription checkRuleInvocationConformantToJudgmentDescription(
			RuleInvocation ruleInvocation) {
		return checkConformanceAgainstJudgmentDescription(
				ruleInvocation,
				ruleInvocation.getJudgmentSymbol(),
				ruleInvocation.getRelationSymbols(),
				ruleInvocation.getExpressions(),
				"Rule invocation",
				XsemanticsPackage.Literals.RULE_INVOCATION.getEIDAttribute(),
				XsemanticsPackage.Literals.RULE_INVOCATION_EXPRESSION__EXPRESSION);
	}

	protected JudgmentDescription checkConformanceAgainstJudgmentDescription(
			EObject element, String judgmentSymbol,
			Iterable<String> relationSymbols,
			Iterable<? extends EObject> elements,
			final String elementDescription, EStructuralFeature elementFeature,
			EStructuralFeature conformanceFeature) {
		JudgmentDescription judgmentDescription = xsemanticsUtils
				.judgmentDescription(element, judgmentSymbol, relationSymbols);
		if (judgmentDescription == null) {
			error("No Judgment description for: "
					+ symbolsRepresentation(judgmentSymbol, relationSymbols),
					elementFeature, IssueCodes.NO_JUDGMENT_DESCRIPTION);
		} else {
			List<JudgmentParameter> judgmentParameters = judgmentDescription
					.getJudgmentParameters();
			Iterator<? extends EObject> elementsIt = elements.iterator();
			for (JudgmentParameter judgmentParameter : judgmentParameters) {
				checkConformance(judgmentParameter, elementsIt.next(),
						elementDescription, conformanceFeature);
			}
		}
		return judgmentDescription;
	}

	protected void checkConformance(JudgmentParameter judgmentParameter, EObject element,
			final String elementDescription, EStructuralFeature feature) {
		JvmTypeReference expected = subtyping.getJvmTypeReference(judgmentParameter);
		JvmTypeReference actual = typingSystem.getType(element);
		if (!subtyping.isConformant(expected, actual)) {
			error(elementDescription + " type " + getNameOfTypes(actual)
					+ " is not subtype of JudgmentDescription declared type "
					+ getNameOfTypes(expected), element, feature,
					IssueCodes.NOT_SUBTYPE);
		}
	}

	protected String symbolsRepresentation(String judgmentSymbol,
			Iterable<String> relationSymbols) {
		return judgmentSymbol + " "
				+ IterableExtensions.join(relationSymbols, " ");
	}

	protected String tupleTypeRepresentation(TupleType tupleType) {
		StringBuilder builder = new StringBuilder();
		Iterator<JvmTypeReference> it = tupleType.iterator();
		while (it.hasNext()) {
			builder.append(getNameOfTypes(it.next()));
			if (it.hasNext())
				builder.append(", ");
		}
		return builder.toString();
	}

	public boolean isEnableWarnings() {
		return enableWarnings;
	}

	public void setEnableWarnings(boolean enableWarnings) {
		this.enableWarnings = enableWarnings;
	}

}
