{{ template "boilerplate" }}

// Code generated by ack-generate. DO NOT EDIT.

package {{ .CRD.Names.Lower }}

import (
	"context"

	"github.com/pkg/errors"
	"github.com/google/go-cmp/cmp"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"sigs.k8s.io/controller-runtime/pkg/client"
	svcsdkapi "github.com/aws/aws-sdk-go/service/{{ .ServiceIDClean }}/{{ .ServiceIDClean }}iface"
	svcapi "github.com/aws/aws-sdk-go/service/{{ .ServiceIDClean }}"
	svcsdk "github.com/aws/aws-sdk-go/service/{{ .ServiceIDClean }}"

	"github.com/crossplane/crossplane-runtime/pkg/meta"
	"github.com/crossplane/crossplane-runtime/pkg/reconciler/managed"
	cpresource "github.com/crossplane/crossplane-runtime/pkg/resource"
	xpv1 "github.com/crossplane/crossplane-runtime/apis/common/v1"

	svcapitypes "github.com/crossplane/provider-aws/apis/{{ .ServiceIDClean }}/{{ .APIVersion}}"
	awsclient "github.com/crossplane/provider-aws/pkg/clients"
)

const (
	errUnexpectedObject = "managed resource is not an {{ .CRD.Names.Camel }} resource"

	errCreateSession = "cannot create a new session"
	errCreate = "cannot create {{ .CRD.Names.Camel }} in AWS"
	errUpdate = "cannot update {{ .CRD.Names.Camel }} in AWS"
	errDescribe = "failed to describe {{ .CRD.Names.Camel }}"
	errDelete = "failed to delete {{ .CRD.Names.Camel }}"
)

type connector struct {
	kube client.Client
	opts []option
}

func (c *connector) Connect(ctx context.Context, mg cpresource.Managed) (managed.ExternalClient, error) {
	cr, ok := mg.(*svcapitypes.{{ .CRD.Names.Camel }})
	if !ok {
		return nil, errors.New(errUnexpectedObject)
	}
	sess, err := awsclient.GetConfigV1(ctx, c.kube, mg, cr.Spec.ForProvider.Region)
	if err != nil {
		return nil, errors.Wrap(err, errCreateSession)
	}
	return newExternal(c.kube, svcapi.New(sess), c.opts), nil
}

func (e *external) Observe(ctx context.Context, mg cpresource.Managed) (managed.ExternalObservation, error) {
{{- if or .CRD.Ops.ReadOne .CRD.Ops.GetAttributes .CRD.Ops.ReadMany }}
	cr, ok := mg.(*svcapitypes.{{ .CRD.Names.Camel }})
	if !ok {
		return managed.ExternalObservation{}, errors.New(errUnexpectedObject)
	}
	if meta.GetExternalName(cr) == "" {
		return managed.ExternalObservation{
			ResourceExists: false,
		}, nil
	}
{{- if .CRD.Ops.ReadOne }}
	input := Generate{{ .CRD.Ops.ReadOne.InputRef.Shape.ShapeName }}(cr)
	if err := e.preObserve(ctx, cr, input); err != nil {
		return managed.ExternalObservation{}, errors.Wrap(err, "pre-observe failed")
	}
	resp, err := e.client.{{ .CRD.Ops.ReadOne.ExportedName }}WithContext(ctx, input)
	if err != nil {
		return managed.ExternalObservation{ResourceExists: false}, awsclient.Wrap(cpresource.Ignore(IsNotFound, err), errDescribe)
	}
{{- else if .CRD.Ops.GetAttributes }}
	input := Generate{{ .CRD.Ops.GetAttributes.InputRef.Shape.ShapeName }}(cr)
	if err := e.preObserve(ctx, cr, input); err != nil {
		return managed.ExternalObservation{}, errors.Wrap(err, "pre-observe failed")
	}
	resp, err := e.client.{{ .CRD.Ops.GetAttributes.ExportedName }}WithContext(ctx, input)
	if err != nil {
		return managed.ExternalObservation{ResourceExists: false}, awsclient.Wrap(cpresource.Ignore(IsNotFound, err), errDescribe)
	}
{{- else if .CRD.Ops.ReadMany }}
	input := Generate{{ .CRD.Ops.ReadMany.InputRef.Shape.ShapeName }}(cr)
	if err := e.preObserve(ctx, cr, input); err != nil {
		return managed.ExternalObservation{}, errors.Wrap(err, "pre-observe failed")
	}
	resp, err := e.client.{{ .CRD.Ops.ReadMany.ExportedName }}WithContext(ctx, input)
	if err != nil {
		return managed.ExternalObservation{ResourceExists: false}, awsclient.Wrap(cpresource.Ignore(IsNotFound, err), errDescribe)
	}
	resp = e.filterList(cr, resp)
	if len(resp.{{ ListMemberNameInReadManyOutput .CRD }}) == 0 {
		return managed.ExternalObservation{ResourceExists: false}, nil
	}
{{- end }}
	currentSpec := cr.Spec.ForProvider.DeepCopy()
	if err := e.lateInitialize(&cr.Spec.ForProvider, resp); err != nil {
		return managed.ExternalObservation{}, errors.Wrap(err, "late-init failed")
	}
	Generate{{ .CRD.Names.Camel }}(resp).Status.AtProvider.DeepCopyInto(&cr.Status.AtProvider)

	upToDate, err := e.isUpToDate(cr, resp)
	if err != nil {
		return managed.ExternalObservation{}, errors.Wrap(err, "isUpToDate check failed")
	}
	return e.postObserve(ctx, cr, resp, managed.ExternalObservation{
		ResourceExists:   true,
		ResourceUpToDate: upToDate,
		ResourceLateInitialized: !cmp.Equal(&cr.Spec.ForProvider, currentSpec),
	}, nil)
{{- else }}
	return e.observe(ctx, mg)
{{- end }}
}

func (e *external) Create(ctx context.Context, mg cpresource.Managed) (managed.ExternalCreation, error) {
	cr, ok := mg.(*svcapitypes.{{ .CRD.Names.Camel }})
	if !ok {
		return managed.ExternalCreation{}, errors.New(errUnexpectedObject)
	}
	cr.Status.SetConditions(xpv1.Creating())
	input := Generate{{ .CRD.Ops.Create.InputRef.Shape.ShapeName }}(cr)
	if err := e.preCreate(ctx, cr, input); err != nil {
		return managed.ExternalCreation{}, errors.Wrap(err, "pre-create failed")
	}
	resp, err := e.client.{{ .CRD.Ops.Create.ExportedName }}WithContext(ctx, input)
	if err != nil {
		return managed.ExternalCreation{}, awsclient.Wrap(err, errCreate)
	}
{{ GoCodeSetCreateOutput .CRD "resp" "cr" 1 false }}
	return e.postCreate(ctx, cr, resp, managed.ExternalCreation{}, err)
}

func (e *external) Update(ctx context.Context, mg cpresource.Managed) (managed.ExternalUpdate, error) {
	{{- if .CRD.Ops.Update }}
	cr, ok := mg.(*svcapitypes.{{ .CRD.Names.Camel }})
	if !ok {
		return managed.ExternalUpdate{}, errors.New(errUnexpectedObject)
	}
	input := Generate{{ .CRD.Ops.Update.InputRef.Shape.ShapeName }}(cr)
	if err := e.preUpdate(ctx, cr, input); err != nil {
		return managed.ExternalUpdate{}, errors.Wrap(err, "pre-update failed")
	}
	resp, err := e.client.{{ .CRD.Ops.Update.ExportedName }}WithContext(ctx, input)
	if err != nil {
		return managed.ExternalUpdate{}, awsclient.Wrap(err, errUpdate)
	}
	return e.postUpdate(ctx, cr, resp, managed.ExternalUpdate{}, err)
	{{- else }}
	return e.update(ctx, mg)
	{{ end }}
}

func (e *external) Delete(ctx context.Context, mg cpresource.Managed) error {
	cr, ok := mg.(*svcapitypes.{{ .CRD.Names.Camel }})
	if !ok {
		return errors.New(errUnexpectedObject)
	}
	cr.Status.SetConditions(xpv1.Deleting())
	{{- if .CRD.Ops.Delete }}
	input := Generate{{ .CRD.Ops.Delete.InputRef.Shape.ShapeName }}(cr)
	ignore, err := e.preDelete(ctx, cr, input)
	if err != nil {
		return errors.Wrap(err, "pre-delete failed")
	}
	if ignore {
		return nil
	}
	resp, err := e.client.{{ .CRD.Ops.Delete.ExportedName }}WithContext(ctx, input)
	return e.postDelete(ctx, cr, resp, awsclient.Wrap(cpresource.Ignore(IsNotFound, err), errDelete))
	{{- else }}
	return e.delete(ctx, mg)
	{{ end }}
}

type option func(*external)

func newExternal(kube client.Client, client svcsdkapi.{{ .SDKAPIInterfaceTypeName }}API, opts []option) *external {
	e := &external{
		kube:           kube,
		client:         client,
		{{- if or .CRD.Ops.ReadOne .CRD.Ops.GetAttributes .CRD.Ops.ReadMany }}
		preObserve:     nopPreObserve,
		postObserve:    nopPostObserve,
		lateInitialize: nopLateInitialize,
		isUpToDate:     alwaysUpToDate,
		{{- else }}
		observe:        nopObserve,
		{{- end }}
		{{- if and .CRD.Ops.ReadMany (not .CRD.Ops.ReadOne) }}
		filterList:     nopFilterList,
		{{- end}}
		preCreate:      nopPreCreate,
		postCreate:     nopPostCreate,
		{{- if .CRD.Ops.Delete }}
		preDelete:      nopPreDelete,
		postDelete:      nopPostDelete,
		{{- else }}
		delete:         nopDelete,
		{{- end }}
		{{- if .CRD.Ops.Update }}
		preUpdate:      nopPreUpdate,
		postUpdate:     nopPostUpdate,
		{{- else }}
		update:         nopUpdate,
		{{- end }}
	}
	for _, f := range opts {
		f(e)
	}
	return e
}

type external struct {
	kube        client.Client
	client      svcsdkapi.{{ .SDKAPIInterfaceTypeName }}API
	{{- if .CRD.Ops.ReadOne }}
	preObserve  func(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.ReadOne.InputRef.Shape.ShapeName }}) error
	postObserve func(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.ReadOne.OutputRef.Shape.ShapeName }}, managed.ExternalObservation, error) (managed.ExternalObservation, error)
	lateInitialize func(*svcapitypes.{{ .CRD.Names.Camel }}Parameters, *svcsdk.{{ .CRD.Ops.ReadOne.OutputRef.Shape.ShapeName }}) error
	isUpToDate     func(*svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.ReadOne.OutputRef.Shape.ShapeName }}) (bool, error)
	{{- else if .CRD.Ops.GetAttributes }}
	preObserve  func(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.GetAttributes.InputRef.Shape.ShapeName }}) error
	postObserve func(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.GetAttributes.OutputRef.Shape.ShapeName }}, managed.ExternalObservation, error) (managed.ExternalObservation, error)
	lateInitialize func(*svcapitypes.{{ .CRD.Names.Camel }}Parameters, *svcsdk.{{ .CRD.Ops.GetAttributes.OutputRef.Shape.ShapeName }}) error
	isUpToDate     func(*svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.GetAttributes.OutputRef.Shape.ShapeName }}) (bool, error)
	{{- else if .CRD.Ops.ReadMany }}
	preObserve  func(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.ReadMany.InputRef.Shape.ShapeName }}) error
	postObserve func(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.ReadMany.OutputRef.Shape.ShapeName }}, managed.ExternalObservation, error) (managed.ExternalObservation, error)
	filterList func(*svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.ReadMany.OutputRef.Shape.ShapeName }}) *svcsdk.{{ .CRD.Ops.ReadMany.OutputRef.Shape.ShapeName }}
	lateInitialize func(*svcapitypes.{{ .CRD.Names.Camel }}Parameters, *svcsdk.{{ .CRD.Ops.ReadMany.OutputRef.Shape.ShapeName }}) error
	isUpToDate     func(*svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.ReadMany.OutputRef.Shape.ShapeName }}) (bool, error)
	{{- else }}
	observe     func(context.Context, cpresource.Managed) (managed.ExternalObservation, error)
	{{- end }}
	preCreate   func(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.Create.InputRef.Shape.ShapeName }}) error
	postCreate  func(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.Create.OutputRef.Shape.ShapeName }}, managed.ExternalCreation, error) (managed.ExternalCreation, error)
	{{- if .CRD.Ops.Delete }}
	preDelete   func(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.Delete.InputRef.Shape.ShapeName }}) (bool, error)
	postDelete  func(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.Delete.OutputRef.Shape.ShapeName }}, error) error
	{{- else }}
	delete      func(context.Context, cpresource.Managed) error
	{{- end }}
	{{- if .CRD.Ops.Update }}
	preUpdate   func(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.Update.InputRef.Shape.ShapeName }}) error
	postUpdate  func(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.Update.OutputRef.Shape.ShapeName }}, managed.ExternalUpdate, error) (managed.ExternalUpdate, error)
	{{- else }}
	update      func(context.Context, cpresource.Managed) (managed.ExternalUpdate, error)
	{{ end }}
}

{{- if .CRD.Ops.ReadOne }}
func nopPreObserve(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.ReadOne.InputRef.Shape.ShapeName }}) error {
	return nil
}

func nopPostObserve(_ context.Context, _ *svcapitypes.{{ .CRD.Names.Camel }}, _ *svcsdk.{{ .CRD.Ops.ReadOne.OutputRef.Shape.ShapeName }}, obs managed.ExternalObservation, err error) (managed.ExternalObservation, error) {
	return obs, err
}
func nopLateInitialize(*svcapitypes.{{ .CRD.Names.Camel }}Parameters, *svcsdk.{{ .CRD.Ops.ReadOne.OutputRef.Shape.ShapeName }}) error {
	return nil
}
func alwaysUpToDate(*svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.ReadOne.OutputRef.Shape.ShapeName }})  (bool, error) {
	return true, nil
}
{{- else if .CRD.Ops.GetAttributes }}
func nopPreObserve(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.GetAttributes.InputRef.Shape.ShapeName }}) error {
	return nil
}

func nopPostObserve(_ context.Context, _ *svcapitypes.{{ .CRD.Names.Camel }}, _ *svcsdk.{{ .CRD.Ops.GetAttributes.OutputRef.Shape.ShapeName }}, obs managed.ExternalObservation, err error) (managed.ExternalObservation, error) {
	return obs, err
}
func nopLateInitialize(*svcapitypes.{{ .CRD.Names.Camel }}Parameters, *svcsdk.{{ .CRD.Ops.GetAttributes.OutputRef.Shape.ShapeName }}) error {
	return nil
}
func alwaysUpToDate(*svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.GetAttributes.OutputRef.Shape.ShapeName }}) (bool, error) {
	return true, nil
}
{{- else if .CRD.Ops.ReadMany }}
func nopPreObserve(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.ReadMany.InputRef.Shape.ShapeName }}) error {
	return nil
}
func nopPostObserve(_ context.Context, _ *svcapitypes.{{ .CRD.Names.Camel }}, _ *svcsdk.{{ .CRD.Ops.ReadMany.OutputRef.Shape.ShapeName }}, obs managed.ExternalObservation, err error) (managed.ExternalObservation, error) {
	return obs, err
}
func nopFilterList(_ *svcapitypes.{{ .CRD.Names.Camel }}, list *svcsdk.{{ .CRD.Ops.ReadMany.OutputRef.Shape.ShapeName }}) *svcsdk.{{ .CRD.Ops.ReadMany.OutputRef.Shape.ShapeName }} {
	return list
}

func nopLateInitialize(*svcapitypes.{{ .CRD.Names.Camel }}Parameters, *svcsdk.{{ .CRD.Ops.ReadMany.OutputRef.Shape.ShapeName }}) error {
	return nil
}
func alwaysUpToDate(*svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.ReadMany.OutputRef.Shape.ShapeName }}) (bool, error) {
	return true, nil
}
{{ else }}
func nopObserve(context.Context, cpresource.Managed) (managed.ExternalObservation, error) {
	return managed.ExternalObservation{}, nil
}
{{ end }}

func nopPreCreate(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.Create.InputRef.Shape.ShapeName }}) error {
	return nil
}
func nopPostCreate(_ context.Context, _ *svcapitypes.{{ .CRD.Names.Camel }}, _ *svcsdk.{{ .CRD.Ops.Create.OutputRef.Shape.ShapeName }}, cre managed.ExternalCreation, err error) (managed.ExternalCreation, error) {
	return cre, err
}
{{- if .CRD.Ops.Delete }}
func nopPreDelete(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.Delete.InputRef.Shape.ShapeName }}) (bool, error) {
	return false, nil
}
func nopPostDelete(_ context.Context, _ *svcapitypes.{{ .CRD.Names.Camel }}, _ *svcsdk.{{ .CRD.Ops.Delete.OutputRef.Shape.ShapeName }}, err error) error {
	return err
}
{{- else }}
func nopDelete(context.Context, cpresource.Managed) error {
	return nil
}
{{- end }}
{{- if .CRD.Ops.Update }}
func nopPreUpdate(context.Context, *svcapitypes.{{ .CRD.Names.Camel }}, *svcsdk.{{ .CRD.Ops.Update.InputRef.Shape.ShapeName }}) error {
	return nil
}
func nopPostUpdate(_ context.Context, _ *svcapitypes.{{ .CRD.Names.Camel }}, _ *svcsdk.{{ .CRD.Ops.Update.OutputRef.Shape.ShapeName }}, upd managed.ExternalUpdate, err error) (managed.ExternalUpdate, error) {
	return upd, err
}
{{- else }}
func nopUpdate(context.Context, cpresource.Managed) (managed.ExternalUpdate, error) {
	return managed.ExternalUpdate{}, nil
}
{{- end }}